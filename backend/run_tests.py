import pytest
import sys

if __name__ == "__main__":
    retcode = pytest.main(["-v", "tests/test_services.py"])
    sys.exit(retcode)
