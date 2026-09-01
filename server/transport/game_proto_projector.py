# coding=utf-8
'''将领域事件和快照转换为协议对象'''

import game.events as events
import proto.generated.game_pb2 as game_pb2

class GameProtoProjector:

    @staticmethod
    def entity_info(snapshot: events.EntitySnapshot) -> game_pb2.EntityInfo:
        info = game_pb2.EntityInfo(
            entity_id=snapshot.entity_id,
            player_name=snapshot.player_name,
            entity_type=snapshot.entity_type,
            x=snapshot.x,
            y=snapshot.y,
            facing_x=snapshot.facing[0],
            facing_y=snapshot.facing[1],
            anim_state=snapshot.anim_state,
            moving=snapshot.moving,
            ai_state=snapshot.ai_state,
        )
        
        combat_info = game_pb2.CombatEntityInfo(
            entity_id=snapshot.entity_id,
            atk_facing=snapshot.combat_snapshot.atk_facing,
            hp=snapshot.combat_snapshot.hp,
            max_hp=snapshot.combat_snapshot.max_hp,
            dead=snapshot.combat_snapshot.dead,
        )
        info.combat_entity_info.CopyFrom(combat_info)

        return info

    @staticmethod
    def movement(moved: events.EntityMovedEvent) -> game_pb2.MovementEntry:
        return game_pb2.MovementEntry(
            entity_id=moved.entity_id,
            x=moved.x,
            y=moved.y,
            moving=moved.moving,
            anim_state=moved.anim_state,
            facing_x=moved.facing[0],
            facing_y=moved.facing[1],
        )

    @staticmethod
    def anim_state(rotate: events.EntityAtkRotateEvent) -> game_pb2.AnimStateDelta:
        return game_pb2.AnimStateDelta(
            entity_id=rotate.entity_id,
            atk_facing=rotate.atk_facing,
        )

    @staticmethod
    def attack_start(event: events.EntityAttackStartEvent) -> game_pb2.WorldEvent:
        return game_pb2.WorldEvent(
            event_id = 1,
            attack_start = game_pb2.AttackStart(
                attacker_id=event.entity_id,
                attack_id=event.attack_id,
                atk_facing=event.atk_facing,
            ),
        )
