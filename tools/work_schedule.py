"""Shared daily model-launch window; existing native runs are never interrupted."""
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

ZONE = ZoneInfo('America/New_York')
START = time(7, 0)
END = time(17, 0)


def status(now=None):
    """Return launch eligibility and next opening; aware input supports deterministic tests."""
    if now is None:
        now = datetime.now(ZONE)
    elif now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('now must be timezone-aware')
    local = now.astimezone(ZONE)
    opened = START <= local.time() < END
    next_day = local.date() if local.time() < START else local.date() + timedelta(days=1)
    next_open = None if opened else datetime.combine(next_day, START, ZONE).isoformat()
    return {'enabled': True, 'timezone': 'America/New_York', 'days': 'every_day',
            'start': '07:00', 'end': '17:00', 'open': opened,
            'next_open_at': next_open, 'policy': 'finish_in_flight'}
