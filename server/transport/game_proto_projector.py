# coding=utf-8
'''将领域事件和快照转换为协议对象'''

import game.events as events
import proto.generated.game_pb2 as game_pb2

event_id = 0

def get_event_id():
    global event_id
    event_id += 1
    return event_id

class GameProtoProjector:

    @staticmethod
    def entity_info(snapshot: events.EntitySnapshot) -> game_pb2.EntityInfo:
        info = game_pb2.EntityInfo(
            entity_id=snapshot.entity_id,
            player_name=snapshot.player_name,
            entity_type=snapshot.entity_type,
            entity_config_key=snapshot.entity_config_key,
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
    def aim_state(rotate: events.EntityAtkRotateEvent) -> game_pb2.AimStateDelta:
        return game_pb2.AimStateDelta(
            entity_id=rotate.entity_id,
            atk_facing=rotate.atk_facing,
        )

    @staticmethod
    def attack_start(event: events.EntityAttackStartEvent) -> game_pb2.WorldEvent:
        return game_pb2.WorldEvent(
            event_id = get_event_id(),
            attack_start = game_pb2.AttackStart(
                attacker_id=event.entity_id,
                attack_id=event.attack_id,
                atk_facing=event.atk_facing,
            ),
        )

    @staticmethod
    def attack_hit(event: events.EntityAttackHitEvent) -> game_pb2.WorldEvent:
        return game_pb2.WorldEvent(
            event_id = get_event_id(),
            attack_hit = game_pb2.AttackHit(
                attacker_id=event.entity_id,
                attack_id=event.attack_id,  
                hit_entity_ids=event.hit_entity_ids,
            ),
        )

    @staticmethod
    def damage_event(event: events.EntityHurtEvent) -> game_pb2.WorldEvent:
        return game_pb2.WorldEvent(
            event_id = get_event_id(),
            damage = game_pb2.DamageEvent(
                target_id=event.entity_id,
                attack_id=event.attack_id,
                damage=event.damage,
                attacker_id=event.attacker_id,
                critical=event.is_critical,
            ),
        )

    @staticmethod
    def health_state(event: events.EntityHealthChangedEvent) -> game_pb2.HealthStateDelta:
        return game_pb2.HealthStateDelta(
            entity_id=event.entity_id,
            hp=event.hp,
            max_hp=event.max_hp,
            dead=event.dead,
        )

    @staticmethod
    def entity_died(event: events.EntityDiedEvent) -> game_pb2.WorldEvent:
        return game_pb2.WorldEvent(
            event_id = get_event_id(),
            entity_dead = game_pb2.EntityDead(
                entity_id=event.entity_id,
            ),
        )

    @staticmethod
    def enemy_budget(event: events.EnemyBudgetData) -> game_pb2.EnemyBudgetData:
        """按现有整数协议发送预算，保留领域快照中的小数精度。"""
        return game_pb2.EnemyBudgetData(
            enemy_type=event.enemy_type,
            budget=int(event.budget),
        )

    @staticmethod
    def level_debug(event: events.LevelDebugEvent) -> game_pb2.LevelDebugData:
        """时间按协议单位取整，已到期的倒计时按零发送。"""
        enemy_budget_data = [GameProtoProjector.enemy_budget(enemy_budget) for enemy_budget in event.enemy_budget]
        return game_pb2.LevelDebugData(
            enemy_budget_data = enemy_budget_data,
            server_tick=event.server_tick,
            cur_stage_id = event.cur_stage_id,
            spwan_time_count_down_ms=max(0, int(event.spwan_time_count_down_ms)),
            stage_time_seconds=int(event.stage_time_seconds),
            enemy_count=event.enemy_count,
            normal_enemy_count=event.normal_enemy_count,
        )
