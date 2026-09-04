# coding=utf-8
''' 生成敌人系统 '''



from game.entity_projector import project_entity_snapshot
from game.systems.comp_system import CompSystem
import game.events as events
import typing
if typing.TYPE_CHECKING:
    import game.commands as command
    import game.world as game_world




class SpawnEnemySystem(CompSystem):
    def apply_command(self, world: "game_world.GameWorld", command: "command.SpawnEnemyCommand") -> list[events.Event]:
        """生成敌人。"""
        enemy = world.create_enemy(
            enemy_type=command.enemy_type,
            x=command.x,
            y=command.y,
        )

        entity_snapshot = project_entity_snapshot(enemy)
        env = events.EntitySpawnedEvent(
            entity_info=entity_snapshot,
        )
        
        return [env]
    
    def update(self, world: "game_world.GameWorld", dt: float) -> list[events.Event]:
        """更新敌人系统。"""
        return []
    