# coding=utf-8
"""应用运行时：将客户端命令分流到会话处理或权威世界。"""

from game.commands import LoginCommand, SessionCommand, WorldCommand, LeaveCommand
from proto.generated import game_pb2
from protocol.contract import ProtocolValidationError
from protocol.router import ClientMessageRouter
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from transport.outbound_queue import OutBoundQueue

class AppRuntime:
    def __init__(self, world):
        self._world = world
        self._connections = ConnectionRegistry.get()
        self._outbound = OutBoundQueue.get()

    def on_client_message(self, context: ConnectionContext, message: game_pb2.ClientMessage):
        try:
            command = ClientMessageRouter.get().to_command(context, message)
        except ProtocolValidationError as error:
            self.reject_command(
                context.connection_id,
                error.command_name,
                error.reason_code,
                error.reason_message,
            )
            return

        if command is None:
            return

        if isinstance(command, SessionCommand):
            self.on_session_command(context, command)
        elif isinstance(command, WorldCommand):
            self.on_world_command(context, command)
        else:
            self.reject_command(
                context.connection_id,
                type(command).__name__,
                "UNSUPPORTED_COMMAND",
                "不支持该命令类型",
            )

    def on_session_command(self, context: ConnectionContext, command: SessionCommand):
        if not isinstance(command, LoginCommand):
            self.reject_command(
                context.connection_id,
                type(command).__name__,
                "UNSUPPORTED_SESSION_COMMAND",
                "不支持该会话命令类型",
            )
            return

        if command.connection_id != context.connection_id:
            self.reject_command(
                context.connection_id,
                "login_request",
                "CONNECTION_MISMATCH",
                "该命令不属于当前连接",
            )
            return

        self._connections.bind_account(
            context.connection_id,
            command.account,
            command.player_name,
        )
        accepted = game_pb2.LoginAccepted(
            account=command.account,
            player_name=command.player_name,
        )
        self._outbound.send_to(context.connection_id, "login_accepted", accepted)

    def on_world_command(self, context: ConnectionContext, command: WorldCommand):
        if command.connection_id != context.connection_id:
            self.reject_command(
                context.connection_id,
                type(command).__name__,
                "CONNECTION_MISMATCH",
                "该命令不属于当前连接",
            )
            return

        if not context.account_id:
            self.reject_command(
                context.connection_id,
                type(command).__name__,
                "AUTH_REQUIRED",
                "进入或控制游戏世界前必须先登录",
            )
            return

        self._world.enqueue_command(command)

    def on_connection_closed(self, context: ConnectionContext):
        if not context.player_entity_id or context.room_id != self._world.room_id:
            return
        self._world.enqueue_command(
            LeaveCommand(
                entity_id=context.player_entity_id,
                connection_id=context.connection_id,
                account=context.account_id,
            )
        )

    def reject_command(
        self,
        connection_id: int,
        command_name: str,
        reason_code: str,
        reason_message: str,
    ):
        rejected = game_pb2.CommandRejected(
            command_name=command_name,
            reason_code=reason_code,
            reason_message=reason_message,
        )
        self._outbound.send_to(connection_id, "command_rejected", rejected)
