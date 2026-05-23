extends TileMap

[gd_resource type="TileSet" format=3 uid="uid://ydwe2v6t82bg"]

[ext_resource type="Texture2D" uid="uid://bs0pfrog57go5" path="res://Asset/TilemapPlaceholders.png" id="1"]
[ext_resource type="Texture2D" uid="uid://cxr5n0osayqoa" path="res://Asset/GrassTiles.png" id="2"]
[ext_resource type="Texture2D" uid="uid://d3g2giu0cbyge" path="res://Asset/DirtTiles.png" id="3"]
[ext_resource type="Texture2D" uid="uid://cwr0386f1qb6t" path="res://Asset/SandTiles.png" id="4"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_obwfr"]
texture = ExtResource("1_ndw88")
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_ro1po"]
texture = ExtResource("2_uueft")
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0
3:0/0 = 0
0:1/0 = 0
1:1/0 = 0
2:1/0 = 0
3:1/0 = 0
0:2/0 = 0
1:2/0 = 0
2:2/0 = 0
3:2/0 = 0
1:3/0 = 0
2:3/0 = 0
3:3/0 = 0

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_qbkht"]
texture = ExtResource("3_i7gjm")
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0
3:0/0 = 0
0:1/0 = 0
1:1/0 = 0
2:1/0 = 0
3:1/0 = 0
0:2/0 = 0
1:2/0 = 0
2:2/0 = 0
3:2/0 = 0
1:3/0 = 0
2:3/0 = 0
3:3/0 = 0

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_n6j4k"]
texture = ExtResource("4_n6mx7")
0:0/0 = 0
1:0/0 = 0
2:0/0 = 0
3:0/0 = 0
0:1/0 = 0
1:1/0 = 0
2:1/0 = 0
3:1/0 = 0
0:2/0 = 0
1:2/0 = 0
2:2/0 = 0
3:2/0 = 0
1:3/0 = 0
2:3/0 = 0
3:3/0 = 0

[resource]
sources/0 = SubResource("TileSetAtlasSource_obwfr")
sources/1 = SubResource("TileSetAtlasSource_ro1po")
sources/2 = SubResource("TileSetAtlasSource_qbkht")
sources/3 = SubResource("TileSetAtlasSource_n6j4k")
