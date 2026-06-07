#!/usr/bin/env python3
from __future__ import annotations

import math
import os
import wave
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BLENDER_DIR = ROOT / "blender"
GLB_DIR = ROOT / "demos" / "glb"
AUDIO_DIR = ROOT / "assets" / "audio"

DEMOS = [
    ("01_scene_settings", "Paper Morning", "Scene settings", (0.94, 0.61, 0.56, 1.0)),
    ("02_groups", "Ribbon Clubs", "Groups", (0.91, 0.71, 0.43, 1.0)),
    ("03_triggers", "Welcome Mat", "Triggers", (0.85, 0.80, 0.45, 1.0)),
    ("04_event_commands", "Postcard Route", "Event commands", (0.62, 0.77, 0.56, 1.0)),
    ("05_animations", "Wind-Up Bloom", "Animations", (0.47, 0.73, 0.65, 1.0)),
    ("06_cameras", "Teacup Close-Up", "Cameras", (0.44, 0.72, 0.78, 1.0)),
    ("07_speakers", "Tiny Chime", "Speakers", (0.51, 0.66, 0.85, 1.0)),
    ("08_rigid_physics", "Tumble Parcel", "Rigid physics", (0.65, 0.61, 0.84, 1.0)),
    ("09_holdables", "Carry The Star", "Holdables", (0.75, 0.59, 0.81, 1.0)),
    ("10_inventory", "Keepsake Pocket", "Inventory", (0.83, 0.58, 0.72, 1.0)),
    ("11_sub_scenes", "Secret Nook", "Sub-scenes", (0.89, 0.56, 0.62, 1.0)),
    ("12_conversations", "Neighbor Note", "Conversations", (0.91, 0.63, 0.52, 1.0)),
    ("13_water", "Puddle Shine", "Water effect", (0.45, 0.72, 0.78, 1.0)),
    ("14_ui_elements", "Paper Buttons", "3D UI elements", (0.54, 0.74, 0.60, 1.0)),
    ("15_frame_events", "Clockwork Spark", "Frame events", (0.88, 0.74, 0.41, 1.0)),
    ("16_physical_puzzle", "Garden Gate", "Physical puzzle", (0.94, 0.52, 0.44, 1.0)),
]


def ensure_dirs() -> None:
    BLENDER_DIR.mkdir(parents=True, exist_ok=True)
    GLB_DIR.mkdir(parents=True, exist_ok=True)
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)


def make_audio() -> None:
    path = AUDIO_DIR / "tiny_chime.wav"
    if path.exists():
        return
    sample_rate = 44100
    duration = 0.55
    frames = int(sample_rate * duration)
    with wave.open(str(path), "w") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(sample_rate)
        for index in range(frames):
            t = index / sample_rate
            envelope = max(0.0, 1.0 - t / duration) ** 2
            sample = math.sin(2.0 * math.pi * 880.0 * t) * envelope * 0.55
            out.writeframesraw(int(sample * 32767).to_bytes(2, "little", signed=True))


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 80


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def cube(name: str, loc: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def sphere(name: str, loc: tuple[float, float, float], radius: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cylinder(name: str, loc: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_camera(name: str, position: tuple[float, float, float], target: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.object.camera_add(location=position)
    cam = bpy.context.object
    cam.name = name
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 30
    return cam


def add_text(name: str, text: str, loc: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.object.text_add(location=loc, rotation=(math.radians(72), 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = 0.34
    obj.data.materials.append(mat)
    return obj


def add_scene_props(demo_id: str, title: str, accent: tuple[float, float, float, float], commands: dict) -> None:
    scene = bpy.context.scene
    scene["fpe_scene_context_props"] = {
        "SkyColor": [accent[0], accent[1], accent[2], 1.0],
        "Gravity": 12.0 if demo_id == "01_scene_settings" else 20.0,
        "BackgroundMusic": [],
        "BackgroundMusicVolume": -18.0,
        "SceneLoadEvents": [{"EventName": "SceneReady"}],
        "SceneUnloadEvents": [],
    }
    scene["fpe_scene_events_context_props"] = {
        "SceneEvents": [
            {"EventName": "SceneReady", "Commands": {"ActivateCamera": "OverviewCamera"}},
            {"EventName": "ActivateDemo", "Commands": commands},
        ]
    }
    scene["fpe_rush_demo"] = {"id": demo_id, "title": title}


def add_base(title: str, accent: tuple[float, float, float, float]) -> dict[str, bpy.types.Object]:
    paper = material("warm_paper", (0.96, 0.90, 0.78, 1.0))
    ink = material("soft_ink", (0.28, 0.22, 0.18, 1.0))
    accent_mat = material("accent", accent)
    shadow = material("shadow_card", (0.62, 0.53, 0.45, 1.0))
    ground = cube("PaperFloor-col", (0, 0, -0.08), (5.2, 3.3, 0.08), paper)
    ground["fpe_context_props"] = {"Groups": "floor,collidable"}
    cube("BackCard", (0, 1.82, 1.2), (4.8, 0.08, 1.4), shadow)
    add_text("TitleLabel", title, (0, 1.68, 2.25), ink)
    add_camera("OverviewCamera", (0, -5.2, 3.1), (0, 0.3, 0.55))
    bpy.ops.object.light_add(type="AREA", location=(0, -2.0, 4.0))
    lamp = bpy.context.object
    lamp.name = "Softbox"
    lamp.data.energy = 420
    lamp.data.size = 4.0
    return {"paper": paper, "ink": ink, "accent": accent_mat, "shadow": shadow, "ground": ground}


def add_player(materials: dict[str, bpy.types.Material]) -> bpy.types.Object:
    player = sphere("FpeRushPlayer", (-1.9, -0.9, 0.45), 0.34, materials["accent"])
    player["fpe_context_props"] = {"Player": 1.0, "Groups": "player_character"}
    player["fpe_character_context_props"] = {
        "WalkSpeedMultiplier": 0.65,
        "RunSpeedMultiplier": 0.85,
        "JumpForceMultiplier": 0.55,
        "FaceMotionDirection": 1.0,
    }
    player["fpe_player_controls_context_props"] = {
        "ThirdPerson": 1.0,
        "CanHoldItems": 1.0,
        "HoldZoneDistance": 1.05,
        "HoldZoneSize": 0.5,
        "StandardCameraHeight": 1.15,
        "StandardCameraDistance": 3.1,
    }
    player["fpe_trigger_events_context_props"] = {"TriggerGroups": "player", "TriggerEvents": []}
    return player


def animate_location(obj: bpy.types.Object, name: str, start: tuple[float, float, float], end: tuple[float, float, float]) -> None:
    obj.location = start
    obj.keyframe_insert("location", frame=1)
    obj.location = end
    obj.keyframe_insert("location", frame=55)
    if obj.animation_data and obj.animation_data.action:
        obj.animation_data.action.name = name
        obj.animation_data.action["fpe_anim_context_props"] = {"Autoplay": 0.0, "Loop": 0.0}
        obj.animation_data.action["fpe_frame_event_context_props"] = {
            "FrameEvents": [{"FrameNumber": 28.0, "EventName": "SparkAtFrame", "FrameTime": 0.466}]
        }


def build_demo(index: int, demo_id: str, title: str, concept: str, accent: tuple[float, float, float, float]) -> None:
    reset_scene()
    mats = add_base(title, accent)
    commands = {"ActivateCamera": "OverviewCamera"}

    if index in {3, 8, 9, 10, 15}:
        add_player(mats)

    if demo_id == "02_groups":
        for i, x in enumerate([-1.2, 0, 1.2]):
            obj = cube(f"RibbonClub{i+1}", (x, 0, 0.28), (0.42, 0.1, 0.42), mats["accent"])
            obj["fpe_context_props"] = {"Groups": "warm_ribbons,collectibles"}
        commands = {"DeleteByGroup": "warm_ribbons"}
    elif demo_id == "03_triggers":
        mat = material("trigger_glass", (accent[0], accent[1], accent[2], 0.25))
        trigger = cube("WelcomeMatTrigger", (0, -0.25, 0.16), (1.4, 0.7, 0.16), mat)
        trigger["fpe_context_props"] = {"Trigger": 1.0, "Groups": "trigger_demo"}
        trigger["fpe_trigger_events_context_props"] = {
            "TriggerGroups": "player",
            "TriggerEvents": [{"TriggerType": 2.0, "EventName": "ActivateDemo"}],
        }
        commands = {"DispatchEvent": "WelcomeMatTriggered"}
    elif demo_id == "04_event_commands":
        add_camera("DetailCamera", (2.8, -2.4, 1.7), (0.2, 0.0, 0.5))
        speaker = sphere("PostcardBell", (0.9, 0.1, 0.45), 0.22, mats["accent"])
        speaker["fpe_context_props"] = {"Speaker": 1.0, "Groups": "postcard_bell"}
        speaker["fpe_speaker_settings_context_props"] = {
            "SpeakerFile": "res://assets/audio/tiny_chime.wav",
            "SpeakerLoop": 0.0,
            "SpeakerVolume": -6.0,
            "SpeakerMaxDistance": 12.0,
            "SpeakerAutoplay": 0.0,
        }
        commands = {"ActivateCamera": "DetailCamera", "SpeakerTrigger": "PostcardBell", "DispatchEvent": "RouteDelivered"}
    elif demo_id == "05_animations":
        bloom = sphere("BloomBud", (0, -0.15, 0.35), 0.25, mats["accent"])
        animate_location(bloom, "Bloom", (0, -0.15, 0.35), (0, -0.15, 1.25))
        commands = {"Animations": "Bloom"}
    elif demo_id == "06_cameras":
        cylinder("Teacup", (0, 0, 0.35), 0.48, 0.45, mats["paper"])
        sphere("SteamHeart", (0.32, -0.1, 0.98), 0.13, mats["accent"])
        add_camera("DetailCamera", (1.7, -1.45, 1.15), (0.1, 0.0, 0.55))
        commands = {"ActivateCamera": "DetailCamera"}
    elif demo_id == "07_speakers":
        chime = sphere("TinyChimeSpeaker", (0, 0, 0.55), 0.32, mats["accent"])
        chime["fpe_context_props"] = {"Speaker": 1.0}
        chime["fpe_speaker_settings_context_props"] = {
            "SpeakerFile": "res://assets/audio/tiny_chime.wav",
            "SpeakerLoop": 0.0,
            "SpeakerVolume": -4.0,
            "SpeakerMaxDistance": 16.0,
            "SpeakerAutoplay": 0.0,
        }
        commands = {"SpeakerTrigger": "TinyChimeSpeaker"}
    elif demo_id == "08_rigid_physics":
        parcel = cube("TumbleParcel-rigid", (0, -0.25, 1.2), (0.34, 0.34, 0.34), mats["accent"])
        parcel["fpe_context_props"] = {"Groups": "rigid_demo"}
        parcel["fpe_physics_context_props"] = {"Mass": 1.2, "GravityScale": 1.0}
        commands = {"DispatchEvent": "ParcelReady"}
    elif demo_id == "09_holdables":
        star = sphere("CarryStar-rigid", (0, -0.3, 0.58), 0.28, mats["accent"])
        star["fpe_context_props"] = {"Holdable": 1.0, "Groups": "holdable_demo"}
        commands = {"DispatchEvent": "StarCanBeHeld"}
    elif demo_id == "10_inventory":
        keepsake = sphere("KeepsakePocket-rigid", (0, -0.2, 0.58), 0.26, mats["accent"])
        keepsake["fpe_context_props"] = {"Holdable": 1.0, "Groups": "inventory_demo"}
        keepsake["fpe_inventory_context_props"] = {"InventoryItemKind": "paper_keepsake", "InventoryItemQuantity": 1}
        commands = {"DispatchEvent": "KeepsakeReady"}
    elif demo_id == "11_sub_scenes":
        host = cube("SecretNook", (0, 0.15, 0.42), (0.9, 0.6, 0.42), mats["accent"])
        host["fpe_context_props"] = {"SubScene": 1.0, "Groups": "sub_scene_host"}
        host["fpe_sub_scene_context_props"] = {
            "SceneFile": "res://demos/glb/11_sub_scenes_nook.glb",
            "AutoLoad": 0.0,
            "Pause": 0.0,
            "ResumeOnUnload": 0.0,
            "UnloadDelay": 0.0,
        }
        commands = {"LoadSubScene": "SecretNook"}
    elif demo_id == "12_conversations":
        note = cube("NeighborNote", (0, -0.1, 0.45), (0.8, 0.05, 0.5), mats["paper"])
        note["fpe_context_props"] = {"Trigger": 1.0, "Groups": "conversation_demo"}
        note["fpe_trigger_events_context_props"] = {"TriggerGroups": "player", "TriggerEvents": [{"TriggerType": 2.0, "EventName": "ActivateDemo"}]}
        commands = {"StartConversation": [{"path": "res://demos/conversations/neighbor_note.tres"}]}
    elif demo_id == "13_water":
        puddle = cylinder("PuddleShine", (0, -0.2, 0.06), 0.78, 0.04, mats["accent"])
        puddle["fpe_context_props"] = {"Water": 1.0, "Groups": "water_demo"}
        commands = {"DispatchEvent": "WaterReady"}
    elif demo_id == "14_ui_elements":
        button = cube("PaperButton", (0, -0.1, 0.48), (0.8, 0.18, 0.38), mats["accent"])
        button["fpe_context_props"] = {"UIElement": 1.0, "Groups": "ui_demo"}
        button["fpe_ui_element_context_props"] = {
            "UIOption": 1.0,
        }
        button["fpe_trigger_events_context_props"] = {
            "TriggerGroups": "ui_cursor",
            "TriggerEvents": [{"TriggerType": 2.0, "EventName": "PaperButtonPressed"}],
        }
        commands = {"DispatchEvent": "PaperButtonPressed"}
    elif demo_id == "15_frame_events":
        spark = sphere("ClockworkSpark", (0, -0.15, 0.35), 0.22, mats["accent"])
        animate_location(spark, "SparkTick", (0, -0.15, 0.35), (1.2, -0.15, 0.35))
        commands = {"Animations": "SparkTick"}
    elif demo_id == "16_physical_puzzle":
        gate = cube("GardenGate-col", (0, 0.35, 0.7), (1.45, 0.16, 0.7), mats["accent"])
        gate["fpe_context_props"] = {"Groups": "moving_gate"}
        animate_location(gate, "GateOpen", (0, 0.35, 0.7), (1.7, 0.35, 0.7))
        trigger = cube("GateBellTrigger", (-1.45, -0.25, 0.35), (0.35, 0.35, 0.35), mats["paper"])
        trigger["fpe_context_props"] = {"Trigger": 1.0, "Speaker": 1.0}
        trigger["fpe_trigger_events_context_props"] = {"TriggerGroups": "player", "TriggerEvents": [{"TriggerType": 2.0, "EventName": "ActivateDemo"}]}
        trigger["fpe_speaker_settings_context_props"] = {
            "SpeakerFile": "res://assets/audio/tiny_chime.wav",
            "SpeakerLoop": 0.0,
            "SpeakerVolume": -5.0,
            "SpeakerMaxDistance": 12.0,
            "SpeakerAutoplay": 0.0,
        }
        commands = {"Animations": "GateOpen", "SpeakerTriggerSelf": True, "DispatchEvent": "GateUnlocked"}
    else:
        marker = sphere("ConceptMarker", (0, -0.2, 0.55), 0.38, mats["accent"])
        marker["fpe_context_props"] = {"Groups": "concept_marker"}

    add_scene_props(demo_id, title, accent, commands)
    blend_path = BLENDER_DIR / f"{demo_id}.blend"
    glb_path = GLB_DIR / f"{demo_id}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        export_extras=True,
        export_cameras=True,
        export_lights=True,
        export_animations=True,
        export_apply=True,
    )


def build_sub_scene() -> None:
    reset_scene()
    mats = add_base("Secret Nook Loaded", (0.89, 0.56, 0.62, 1.0))
    gem = sphere("NookGem", (0, -0.1, 0.62), 0.28, mats["accent"])
    gem["fpe_context_props"] = {"Groups": "secret_nook_reward"}
    add_scene_props("11_sub_scenes_nook", "Secret Nook Loaded", (0.89, 0.56, 0.62, 1.0), {"DispatchEvent": "NookLoaded"})
    bpy.ops.wm.save_as_mainfile(filepath=str(BLENDER_DIR / "11_sub_scenes_nook.blend"))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_DIR / "11_sub_scenes_nook.glb"),
        export_format="GLB",
        export_extras=True,
        export_cameras=True,
        export_lights=True,
        export_animations=True,
        export_apply=True,
    )


def main() -> None:
    ensure_dirs()
    make_audio()
    for index, data in enumerate(DEMOS, start=1):
        build_demo(index, *data)
    build_sub_scene()


if __name__ == "__main__":
    main()
