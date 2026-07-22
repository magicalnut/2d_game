import os
import random

ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

def b58encode_int(n: int) -> str:
    if n == 0:
        return ALPHABET[0]
    res = []
    while n > 0:
        n, rem = divmod(n, 58)
        res.append(ALPHABET[rem])
    return ''.join(reversed(res))

def godot_uid():
    """生成一个 uid://xxxxxxxxxxxxxxxx 格式的 Godot UID"""
    n = random.getrandbits(64)
    s = b58encode_int(n)
    # 补齐到 13 位
    s = s.rjust(13, '1')
    return f"uid://{s}"

PLAYER_SHEET_UID = godot_uid()
print(f"player_sheet uid: {PLAYER_SHEET_UID}")

project_root = r"F:\GodotProduction\character-design"

# 1. player_sheet.png.import
import_hash = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"
import_path = f"res://.godot/imported/player_sheet.png-{import_hash}.ctex"
player_import = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{PLAYER_SHEET_UID}"
path="{import_path}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://Assets/Sprites/Characters/Player/player_sheet.png"
dest_files=["{import_path}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

with open(os.path.join(project_root, "Assets", "Sprites", "Characters", "Player", "player_sheet.png.import"), "w", encoding="utf-8") as f:
    f.write(player_import)
print("Wrote player_sheet.png.import")

# 2. player.tscn
# 生成 AtlasTexture 资源
atlas_ids = []
animations = []

# 动画定义: name -> (row, [cols])
anim_defs = {
    "back": (0, list(range(9))),
    "left": (1, list(range(9))),
    "toward": (2, list(range(9))),
    "right": (3, list(range(9))),
    "idle_back": (0, [0]),
    "idle_left": (1, [0]),
    "idle_toward": (2, [0]),
    "idle_right": (3, [0]),
}

def rand_id():
    return "".join(random.choices("abcdefghijklmnopqrstuvwxyz0123456789", k=5))

sub_resources = []
anim_entries = []

for anim_name, (row, cols) in anim_defs.items():
    frame_refs = []
    for c in cols:
        sub_id = "AtlasTexture_" + rand_id()
        atlas_ids.append(sub_id)
        region = f"Rect2({c*64}, {row*64}, 64, 64)"
        sub_resources.append(f"""[sub_resource type="AtlasTexture" id="{sub_id}"]
atlas = ExtResource("1_player")
region = {region}
""")
        frame_refs.append(f"""{{
"duration": 1.0,
"texture": SubResource("{sub_id}")
}}""")
    frames_str = ", ".join(frame_refs)
    speed = 10.0 if not anim_name.startswith("idle") else 1.0
    loop = "true" if not anim_name.startswith("idle") else "true"
    # idle 也 loop，但 1 帧 loop 其实就是静止
    anim_entries.append(f"""{{
"frames": [{frames_str}],
"loop": {loop},
"name": &"{anim_name}",
"speed": {speed}
}}""")

spriteframes_id = "SpriteFrames_" + rand_id()
sub_resources.append(f"""[sub_resource type="SpriteFrames" id="{spriteframes_id}"]
animations = [{", ".join(anim_entries)}]
""")

capsule_id = "CapsuleShape2D_" + rand_id()
sub_resources.append(f"""[sub_resource type="CapsuleShape2D" id="{capsule_id}"]
radius = 12.0
height = 40.0
""")

player_tscn = f"""[gd_scene format=3 uid="{godot_uid()}"]

[ext_resource type="Texture2D" uid="{PLAYER_SHEET_UID}" path="res://Assets/Sprites/Characters/Player/player_sheet.png" id="1_player"]
[ext_resource type="Script" path="res://Assets/Scripts/player.gd" id="2_player_script"]

{chr(10).join(sub_resources)}
[node name="Player" type="CharacterBody2D"]
script = ExtResource("2_player_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
sprite_frames = SubResource("{spriteframes_id}")
animation = &"idle_toward"
frame_progress = 0.0

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, 14)
shape = SubResource("{capsule_id}")

[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 8.0
limit_left = 0
limit_top = 0
limit_right = 2560
limit_bottom = 1440
limit_smoothed = true
editor_draw_screen = false
"""

with open(os.path.join(project_root, "Assets", "Sprites", "Characters", "Player", "player.tscn"), "w", encoding="utf-8") as f:
    f.write(player_tscn)
print("Wrote player.tscn")

# 3. player.gd
player_gd = """extends CharacterBody2D

@export var speed: float = 220.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing: String = "toward"

func _ready() -> void:
    sprite.play("idle_toward")

func _physics_process(_delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = input_dir * speed

    if input_dir.x < 0:
        facing = "left"
    elif input_dir.x > 0:
        facing = "right"
    elif input_dir.y < 0:
        facing = "back"
    elif input_dir.y > 0:
        facing = "toward"

    if input_dir != Vector2.ZERO:
        sprite.play(facing)
    else:
        sprite.play("idle_" + facing)

    move_and_slide()
"""

scripts_dir = os.path.join(project_root, "Assets", "Scripts")
os.makedirs(scripts_dir, exist_ok=True)
with open(os.path.join(scripts_dir, "player.gd"), "w", encoding="utf-8") as f:
    f.write(player_gd)
print("Wrote player.gd")

# 4. main.tscn
BG_UID = "uid://cbg1ruinsv6bg0"  # battle_bg.png 的 uid（已在 .import 中）
PLAYER_SCENE_UID = godot_uid()
main_tscn = f"""[gd_scene format=3 uid="{godot_uid()}"]

[ext_resource type="Texture2D" uid="{BG_UID}" path="res://Assets/Backgrounds/battle_bg.png" id="1_bg"]
[ext_resource type="PackedScene" uid="{PLAYER_SCENE_UID}" path="res://Assets/Sprites/Characters/Player/player.tscn" id="2_player"]

[node name="Main" type="Node2D"]

[node name="Background" type="Sprite2D" parent="."]
position = Vector2(1280, 720)
texture = ExtResource("1_bg")
centered = true

[node name="Player" parent="." instance=ExtResource("2_player")]
position = Vector2(1280, 720)
"""

with open(os.path.join(project_root, "main.tscn"), "w", encoding="utf-8") as f:
    f.write(main_tscn)
print("Wrote main.tscn")

# 5. 更新 project.godot
project_path = os.path.join(project_root, "project.godot")
with open(project_path, "r", encoding="utf-8") as f:
    content = f.read()

# 添加 main_scene
if "run/main_scene" not in content:
    content = content.replace(
        'config/icon="res://icon.svg"',
        'config/icon="res://icon.svg"\nrun/main_scene="res://main.tscn"'
    )

# 添加输入映射
input_section = '''[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"echo":false,"shortcut":false,"location":0,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"echo":false,"shortcut":false,"location":0,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"echo":false,"shortcut":false,"location":0,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"echo":false,"shortcut":false,"location":0,"script":null)
]
}
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"echo":false,"shortcut":false,"location":0,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"echo":false,"shortcut":false,"location":0,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"echo":false,"shortcut":false,"location":0,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"echo":false,"shortcut":false,"location":0,"script":null)
]
}
'''

if "[input]" not in content:
    content = content + "\n" + input_section

with open(project_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated project.godot")

print("\nAll player assets generated.")
print(f"Player scene uid: {PLAYER_SCENE_UID}")
print("NOTE: Please open the project in Godot once to regenerate correct UIDs and import hashes.")
