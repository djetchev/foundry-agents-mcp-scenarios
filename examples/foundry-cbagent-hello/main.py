"""HelloWorld agent built on the Azure AI Foundry CB Agent framework."""

import datetime

from azure.ai.agentserver.core import FoundryCBAgent
from azure.ai.agentserver.core.models import Response
from azure.ai.agentserver.core.models.projects import (
    ItemContentOutputText,
    ResponsesAssistantMessageItemResource,
)


class HelloWorldAgent(FoundryCBAgent):
    """A minimal agent that returns a static 'Hello, World!' response."""

    async def agent_run(self, context):
        """Process a single agent turn and return a greeting.

        Args:
            context: The agent execution context provided by the framework.

        Returns:
            A Response containing a simple hello-world text message.
        """
        return Response(
            id="hello-world",
            created_at=int(datetime.datetime.now(datetime.timezone.utc).timestamp()),
            output=[
                ResponsesAssistantMessageItemResource(
                    status="completed",
                    content=[
                        ItemContentOutputText(
                            text="Hello, World!",
                            annotations=[],
                        )
                    ],
                )
            ],
        )


if __name__ == "__main__":
    HelloWorldAgent().run()
