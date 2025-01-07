"""Find Makefile targets and descriptions."""  # noqa: INP001
import re
import sys

help_items = {
    parts[0]: " ".join(parts[1:])  # pylint: disable=used-before-assignment
    for line in sys.stdin
    if (parts := re.split(r"\s+", re.sub(r"\x1b\[\d+m", "", line)))
}
for target, desc in help_items.items():
    print(f"{target:<20}{desc}")
