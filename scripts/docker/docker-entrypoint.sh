#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob


echo "[INFO]: Running 'cron' docker-entrypoint.sh..."


_run()
{
	echo "[INFO]: Testing '/etc/crontab'..."
	crontab -n /etc/crontab || exit 2
	echo -e "[OK]: Done.\n"

	local _cron_file
	for _cron_file in /etc/cron.d/*; do
		[ -f "${_cron_file}" ] || continue

		echo "[INFO]: Testing '${_cron_file}'..."
		crontab -n "${_cron_file}" || exit 2
		echo -e "[OK]: Done.\n"
	done

	echo "[INFO]: Starting cron..."
	exec tini -- cron -f
}


main()
{
	umask 0002 || exit 2

	chown -Rc "${USER}:${GROUP}" /app/cron /var/log/cron || exit 2
	find /app/cron -type d -exec chmod 770 {} + || exit 2
	find /app/cron/configs -type f ! -name '.gitkeep' -exec chmod 660 {} + || exit 2
	find /app/cron/scripts -type f ! -name '.gitkeep' -exec chmod 770 {} + || exit 2
	find /app/cron -type d -exec chmod ug+s {} + || exit 2
	find /var/log/cron -type d -exec chmod 775 {} + || exit 2
	find /var/log/cron -type f -exec chmod 664 {} + || exit 2
	find /var/log/cron -type d -exec chmod +s {} + || exit 2

	local _cron_period
	local _cron_file
	local _base_name

	for _cron_period in hourly daily weekly monthly; do
		[ -d "/app/cron/scripts/periodic/cron.${_cron_period}" ] || continue

		for _cron_file in /app/cron/scripts/periodic/cron."${_cron_period}"/*; do
			[ -f "${_cron_file}" ] || continue
			_base_name="$(basename "${_cron_file}")"

			case "${_base_name}" in
				.git*|.placeholder|.DS_Store|.Thumbs.db|Thumbs.db)
					continue;;
			esac

			if [[ ! "${_base_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
				echo "[ERROR]: Invalid filename - '${_base_name}'!" >&2
				exit 2
			fi

			cp -vf "${_cron_file}" "/etc/cron.${_cron_period}/" || exit 2
		done
	done

	for _cron_file in /app/cron/configs/cron.d/*; do
		[ -f "${_cron_file}" ] || continue
		_base_name="$(basename "${_cron_file}")"

		case "${_base_name}" in
			.git*|.placeholder|.DS_Store|.Thumbs.db|Thumbs.db)
				continue;;
		esac

		if [[ ! "${_base_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
			echo "[ERROR]: Invalid filename - '${_base_name}'!" >&2
			exit 2
		fi

		cp -vf "${_cron_file}" /etc/cron.d/ || exit 2
	done

	if [ -f /app/cron/configs/crontab ]; then
		cp -vf /app/cron/configs/crontab /etc/crontab || exit 2
	fi

	chown -Rc root:root /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly || exit 2
	find /etc/cron.d -type d -exec chmod -c 755 {} + || exit 2
	find /etc/crontab /etc/cron.d -type f ! -name '.gitkeep' -exec chmod -c 644 {} + || exit 2
	find /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type d -exec chmod -c 755 {} + || exit 2
	find /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type f ! -name '.placeholder' ! -name '.gitkeep' -exec chmod -c 755 {} + || exit 2

	echo ""


	if [ "$(tail -c 1 /etc/crontab | wc -l)" -eq 0 ]; then
		echo "" >> /etc/crontab || exit 2
	fi

	for _cron_file in /etc/cron.d/*; do
		[ -f "${_cron_file}" ] || continue

		if [ "$(tail -c 1 "${_cron_file}" | wc -l)" -eq 0 ]; then
			echo "" >> "${_cron_file}" || exit 2
		fi
	done
	echo ""


	echo "[INFO]: Listing active cronjob entries in '/etc/crontab':"
	grep -vE '^[[:space:]]*(#|$)' /etc/crontab || true
	echo -e "[OK]: Done.\n"

	for _cron_file in /etc/cron.d/*; do
		[ -f "${_cron_file}" ] || continue

		echo "[INFO]: Listing active cronjob entries in '${_cron_file}':"
		grep -vE '^[[:space:]]*(#|$)' "${_cron_file}" || true
		echo -e "[OK]: Done.\n"
	done


	printenv | grep -vE '^(GROUP|HOSTNAME|PWD|HOME|GPG_KEY|TERM|USER|GID|SHLVL|UID|_)=' > /etc/environment || exit 2
	if [ -f /etc/environment ]; then
		chmod 644 /etc/environment || exit 2
	fi


	## Parsing input:
	case ${1:-} in
		"" | -s | --start | start | --run | run)
			_run;;
		-b | --bash | bash | /bin/bash)
			shift
			if [ -z "${*:-}" ]; then
				echo "[INFO]: Starting bash..."
				exec /bin/bash
			else
				echo "[INFO]: Executing command -> ${*}"
				exec /bin/bash -c "${*}"
			fi
			exit 0;;
		*)
			echo "[ERROR]: Failed to parse input -> ${*}!" >&2
			echo "[INFO]: USAGE: ${0}  -s, --start, start | -b, --bash, bash, /bin/bash"
			exit 1;;
	esac
}

main "$@"
