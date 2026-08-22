# coding=utf-8

''' 应用运行时 '''



from game.commands import SessionCommand, WorldCommand
from proto.generated import game_pb2
from protocol.router import ClientMessageRouter
from transport import connection_registry



class AppRuntime:

    def on_client_message(self, context: connection_registry.ConnectionContext, message: game_pb2.ClientMessage):
        command = ClientMessageRouter.get().to_command(context, message)

        if command is not None:
            return

        if isinstance(command, SessionCommand):
            self.on_session_command(context, command)
        elif isinstance(command, WorldCommand):
            self.on_world_command(context, command)