#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob


echo "[INFO]: Backup job started at - $(date '+%Y-%m-%dT%H:%M:%S%z')."

## --- Base --- ##
if ! command -v tar >/dev/null 2>&1; then
	echo "[ERROR]: Not found 'tar' command, please install it first!" >&2
	exit 1
fi
## --- Base --- ##


## --- Variables --- ##
# Load from environment variables:
STORAGE_DIR="${STORAGE_DIR:-/var/lib/storage}"
BACKUPS_DIR="${BACKUPS_DIR:-/var/lib/backups}"
BACKUP_UID="${BACKUP_UID:-1000}"
BACKUP_GID="${BACKUP_GID:-11000}"
## --- Variables --- ##


## --- Validation --- ##
if [ ! -d "${STORAGE_DIR}" ]; then
	echo "[ERROR]: Storage directory not found: '${STORAGE_DIR}'." >&2
	exit 1
fi

if [ ! -d "${BACKUPS_DIR}" ]; then
	mkdir -pv "${BACKUPS_DIR}" || exit 2
fi
chown -c "${BACKUP_UID}:${BACKUP_GID}" "${BACKUPS_DIR}" || exit 2
chmod -c 770 "${BACKUPS_DIR}" || exit 2
## --- Validation --- ##


## --- Functions --- ##
_backup_data_dir()
{
	local _data_dir="${1:-}"
	local _data_dir_name
	local _backup_dir
	local _backup_file_path

	_data_dir_name="$(basename "${_data_dir}")"
	_backup_dir="${BACKUPS_DIR}/${_data_dir_name}"
	if [ ! -d "${_backup_dir}" ]; then
		mkdir -pv "${_backup_dir}" || exit 2
	fi
	chown -c "${BACKUP_UID}:${BACKUP_GID}" "${_backup_dir}" || exit 2
	chmod -c 770 "${_backup_dir}" || exit 2

	_backup_file_path="${_backup_dir}/${_data_dir_name}.$(date -u '+%Y%m%d_%H%M%S').tar.gz"
	echo "[INFO]: Creating backup file: '${_backup_file_path}'..."

	# Compress even if files changed during the backup process, but warn about it.
	tar -czhpf "${_backup_file_path}" \
		--warning=no-file-changed \
		-C "$(dirname "${_data_dir}")" \
		"${_data_dir_name}" || exit 2

	chown -c "${BACKUP_UID}:${BACKUP_GID}" "${_backup_file_path}" || exit 2
	chmod -c 660 "${_backup_file_path}" || exit 2
	echo "[OK]: Backup completed: '${_backup_file_path}'."
}
## --- Functions --- ##

## --- Main --- ##
main()
{
	local _data_dir
 	local _found_dir=false

	echo "[INFO]: Backing up storage directory: '${STORAGE_DIR}'..."
	for _data_dir in "${STORAGE_DIR}"/*; do
		if [ -d "${_data_dir}" ]; then
 			_found_dir=true
			_backup_data_dir "${_data_dir}"
		fi
	done

 	if [ "${_found_dir}" != true ]; then
 		echo "[WARN]: No directories found under storage directory: '${STORAGE_DIR}'!"
 	fi
	echo "[OK]: Successfully backed up storage directory: '${STORAGE_DIR}'."
}

main
## --- Main --- ##

echo -e "[OK]: Backup job finished at - $(date '+%Y-%m-%dT%H:%M:%S%z').\n"
