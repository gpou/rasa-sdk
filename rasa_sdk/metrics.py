from typing import Any

from prometheus_client.metrics import Counter


class Metrics:
    def __init__(self):
        self.metrics = {"ACTION_COUNT": Counter('action_count',
                                                'Action Count',
                                                ['action_name'])}

    def get_metrics(self) -> Any:
        return self.metrics
