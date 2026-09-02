# coding=utf-8
"""定向矩形与圆形碰撞的回归测试。"""

import math
import unittest

from game.tools.collision import Circle, Rect, intersect_rect_circle


class IntersectRectCircleTests(unittest.TestCase):
    """验证攻击矩形的正面、边缘、角落和朝向。"""

    def setUp(self):
        self.rect = Rect(
            pos=(0.0, 0.0),
            distance=1.0,
            length=4.0,
            width=2.0,
            direction=0.0,
        )

    def test_circle_center_inside_rect_intersects(self):
        circle = Circle(pos=(3.0, 0.0), radius=0.1)

        self.assertTrue(intersect_rect_circle(self.rect, circle))

    def test_circle_tangent_to_side_intersects(self):
        circle = Circle(pos=(3.0, 2.0), radius=1.0)

        self.assertTrue(intersect_rect_circle(self.rect, circle))

    def test_circle_tangent_to_corner_intersects(self):
        circle = Circle(pos=(6.0, 2.0), radius=math.sqrt(2.0))

        self.assertTrue(intersect_rect_circle(self.rect, circle))

    def test_circle_outside_corner_does_not_intersect(self):
        circle = Circle(pos=(6.0, 2.0), radius=1.4)

        self.assertFalse(intersect_rect_circle(self.rect, circle))

    def test_circle_tangent_to_near_edge_intersects(self):
        circle = Circle(pos=(0.5, 0.0), radius=0.5)

        self.assertTrue(intersect_rect_circle(self.rect, circle))

    def test_rotated_rect_uses_attack_direction(self):
        rect = Rect(
            pos=(0.0, 0.0),
            distance=1.0,
            length=4.0,
            width=2.0,
            direction=math.pi / 2.0,
        )

        self.assertTrue(intersect_rect_circle(rect, Circle(pos=(0.0, 3.0), radius=0.1)))
        self.assertFalse(intersect_rect_circle(rect, Circle(pos=(1.2, 3.0), radius=0.1)))


if __name__ == "__main__":
    unittest.main()
