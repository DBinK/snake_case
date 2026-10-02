class_name MonoFont
extends RefCounted
## 统一获取等宽字体。SystemFont 不支持 font_size，字号在调用处设置。

static func get_mono() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "Consolas", "Courier New", "monospace"])
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f