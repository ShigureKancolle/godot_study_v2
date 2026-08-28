# coding=utf-8
"""命令校验、移动约束和登录命令流的回归测试。"""

import math
import unittest

from app.app_runtime import AppRuntime
from game.commands import JoinCommand, MoveCommand
from game.events import CommandRejectedEvent
from game.model.components import MovementComponent, TransformComponent
from game.model.combat_component import CombatComponent
from game.world import GameWorld
from proto.generated import game_pb2
from protocol.contract import ProtocolValidationError, validate_move_intent
from protocol.handlers.login_handler import login_handle
from transport.connection_registry import ConnectionContext, ConnectionRegistry
from transport.outbound_queue import OutBoundQueue


class MovementValidationTests(unittest.TestCase):
    def setUp(self):
        self.world = GameWorld()
        self.world.enqueue_command(JoinCommand(connection_id=11, account="account-1", player_name="P1"))
        self.world.step(1.0 / 30.0)
        self.player = self.world.get_entities()[0]

    def test_protocol_rejects_non_finite_direction(self):
        for invalid in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(invalid=invalid):
                with self.assertRaises(ProtocolValidationError) as raised:
                    validate_move_intent(game_pb2.MoveIntent(dir_x=invalid, dir_y=0.0, moving=True))
                self.assertEqual("NON_FINITE_DIRECTION", raised.exception.reason_code)

    def test_world_rejects_non_finite_direction_without_corrupting_position(self):
        self.world.enqueue_command(MoveCommand(
            entity_id=self.player.entity_id,
            connection_id=11,
            dir_x=float("nan"),
            dir_y=0.0,
            moving=True,
        ))
        result = self.world.step(1.0 / 30.0)
        transform = self.player.get_component(TransformComponent)

        self.assertTrue(math.isfinite(transform.x))
        self.assertTrue(math.isfinite(transform.y))
        rejection = next(event for event in result.events if isinstance(event, CommandRejectedEvent))
        self.assertEqual("NON_FINITE_DIRECTION", rejection.reason_code)
        self.assertEqual(11, rejection.connection_id)

    def test_locked_entity_stops_existing_movement(self):
        self._start_moving()
        movement = self.player.get_component(MovementComponent)
        transform = self.player.get_component(TransformComponent)
        position_before_lock = (transform.x, transform.y)

        movement.is_locked = True
        self.world.step(1.0)

        self.assertEqual(position_before_lock, (transform.x, transform.y))
        self.assertFalse(movement.moving)

    def test_dead_entity_stops_existing_movement(self):
        self._start_moving()
        combat = self.player.get_component(CombatComponent)
        transform = self.player.get_component(TransformComponent)
        position_before_death = (transform.x, transform.y)

        combat.is_dead = True
        self.world.step(1.0)

        self.assertEqual(position_before_death, (transform.x, transform.y))
        self.assertFalse(self.player.get_component(MovementComponent).moving)

    def _start_moving(self):
        self.world.enqueue_command(MoveCommand(
            entity_id=self.player.entity_id,
            connection_id=11,
            dir_x=1.0,
            dir_y=0.0,
            moving=True,
        ))
        self.world.step(1.0)


class LoginCommandFlowTests(unittest.TestCase):
    def setUp(self):
        self.registry = ConnectionRegistry.get()
        self.registry.connection_by_id.clear()
        self.outbound = OutBoundQueue.get()
        while not self.outbound.queue.empty():
            self.outbound.queue.get_nowait()

    def test_login_handler_only_builds_command_then_app_runtime_binds_session(self):
        context = ConnectionContext(connection_id=71, websocket=None)
        self.registry.connection_by_id[context.connection_id] = context
        request = game_pb2.LoginRequest(account=" account-71 ", player_name=" Player ")

        command = login_handle(context, request)
        self.assertEqual("", context.account_id)

        AppRuntime(GameWorld()).on_session_command(context, command)

        self.assertEqual("account-71", context.account_id)
        self.assertEqual("Player", context.player_name)
        packet = self.outbound.queue.get_nowait()
        envelope = game_pb2.ServerMessage.FromString(packet.payload)
        self.assertEqual("login_accepted", envelope.WhichOneof("payload"))


if __name__ == "__main__":
    unittest.main()
