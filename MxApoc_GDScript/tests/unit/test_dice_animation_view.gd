extends TestBase

## 骰子演出重入：GAME_EVENT 与 INPUT_REQUEST 同时触发时不得叠播第二轮。


func test_play_while_playing_does_not_restart() -> void:
	var view := DiceAnimationView.new()
	add_child_autofree(view)
	await wait_idle_frames(1)
	view._playing = true
	view._name_label.text = "original"
	var holder := {"done": false}
	_await_play(view, holder)
	await wait_idle_frames(2)
	assert_eq(view._name_label.text, "original", "重入不应开始新一轮")
	assert_false(holder["done"], "仍在播放时应继续等待")
	view._playing = false
	await wait_idle_frames(2)
	assert_true(holder["done"], "上一轮结束后重入等待应返回")
	assert_eq(view._name_label.text, "original", "等待返回后仍不应重播")


func _await_play(view: DiceAnimationView, holder: Dictionary) -> void:
	await view.play(3, 4, "新检定", "")
	holder["done"] = true
