import types
from .utils import Utils


class ThresholdCounter:
    """
    ThresholdCounter is a helper class that counts ticks and alarms
    when the threshold is reached.
    """

    def __init__(self, threshold=3):
        """
        Initializes an instanceself.
        threshold         An integer defining the threshold.
        """
        Utils.is_type(threshold, types.IntType)
        self.__cnt = 0
        self.__thr = threshold

    def tick(self):
        """
        Counts one tick.
        """
        self.__cnt += 1

    def reset(self):
        """
        Resets the counter.
        """
        self.__cnt == 0

    def limit(self):
        """
        Returns True when the threshold is met.
        """
        return self.__cnt >= self.__thr
