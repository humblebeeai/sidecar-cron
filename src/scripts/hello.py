#!/usr/bin/env python3
# flake8: noqa

import os

os.environ["BEANS_LOGGING_AUTO_COLORIZED"] = "false"

from potato_util.dt import now_utc_dt
from beans_logging.auto import logger


def main() -> None:
    logger.info(f"Hello world - {now_utc_dt().isoformat()}")
    return


if __name__ == "__main__":
    main()
