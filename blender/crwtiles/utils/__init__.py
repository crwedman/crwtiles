import logging

addon_name = __name__.split('.')[0]  # Get the root add-on name
logger = logging.getLogger(addon_name)
logger.setLevel(logging.DEBUG)

console_handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s %(levelname)-8s [%(filename)s:%(lineno)d] %(message)s')


def registerLogger():
    global console_handler

    if not logger.hasHandlers():
        console_handler.setLevel(logging.DEBUG)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

    logger.info(f"Registered logger: {addon_name}")

def unregisterLogger():
    global console_handler
    logger.info(f"Unregistering logger: {addon_name}")
    if console_handler: logger.removeHandler(console_handler)

