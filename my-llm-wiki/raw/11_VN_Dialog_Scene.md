# [기획 11] VN 스타일 대사창 & 플레이어 입력 UI

## 1. 목표

기존 `DialoguePanel` 은 전체 스크립트를 한 번에 렌더링하는 편집기 스타일이었다.  
이를 비주얼 노벨 관습에 맞게 재설계한다.

- 하단 메세지박스에 타이핑 이펙트로 대사 출력
- 화자 이름 탭 표시
- 스크립트 출력 중 플레이어 입력 완전 차단
- 출력 완료 후 입력창 활성화 및 클릭 시 세로 확장

---

## 2. 씬 계층 변경

### 2.1 제거된 노드

```text
UiLayer/DialoguePanel          (PanelContainer)
  └─ Margin/VBox
       ├─ StoryScroll           (ScrollContainer)
       │    └─ StoryVBox/ScriptLabel (RichTextLabel)
       ├─ InputEdit             (TextEdit)
       ├─ ControlsRow           (HBoxContainer)
       └─ FooterStatusLabel     (Label)
```

### 2.2 추가된 노드

```text
UiLayer/VnDialogLayer          (VBoxContainer) — 화면 하단 38% 고정
  ├─ SpeakerRow                (HBoxContainer)
  │    ├─ SpeakerTab           (PanelContainer)
  │    │    └─ SpeakerTabMargin/SpeakerName (Label)
  │    └─ SpeakerRowSpacer     (Control, stretch)
  ├─ DialogBox                 (PanelContainer)
  │    └─ DialogMargin/DialogueLabel (RichTextLabel)
  └─ PlayerInputPanel          (PanelContainer)
       └─ PlayerInputMargin/PlayerInputVBox (VBoxContainer)
            ├─ InputEdit       (TextEdit)
            ├─ ControlsRow     (HBoxContainer)
            └─ FooterStatusLabel (Label)
```

### 2.3 앵커 설정

`VnDialogLayer` 는 `UiLayer` 안에서 다음 앵커로 고정된다.

| 속성 | 값 |
|------|----|
| anchor_top | 0.62 |
| anchor_bottom | 1.0 |
| offset_left | 16 |
| offset_right | -16 |
| offset_bottom | -12 |

캐릭터 이미지는 화면 상단 ~96% 까지 채워지며, 하단 대사창과 자연스럽게 겹친다.

---

## 3. 타이핑 이펙트

### 3.1 동작 원리

`RichTextLabel.visible_characters` 를 Tween 으로 0 → 전체 글자수까지 애니메이션한다.  
BBCode(`[color]`, `[i]`, `[b]`) 서식은 그대로 유지된다.

```gdscript
func _start_typing_effect(full_text: String) -> void:
    m_dialogue_label.text = full_text
    m_dialogue_label.visible_characters = 0
    var total_chars := m_dialogue_label.get_total_character_count()
    var duration := maxf(float(total_chars) / TYPING_CHARS_PER_SEC, 0.1)
    m_typing_tween = create_tween()
    m_typing_tween.tween_property(m_dialogue_label, "visible_characters", total_chars, duration)
        .set_trans(Tween.TRANS_LINEAR)
    m_typing_tween.tween_callback(_on_typing_finished)
```

### 3.2 속도 상수

| 상수 | 기본값 | 설명 |
|------|--------|------|
| `TYPING_CHARS_PER_SEC` | 30.0 | 초당 출력 글자수 |

속도를 올리려면 이 상수를 높인다. 최소 duration 은 0.1초로 고정.

### 3.3 완료 처리

```gdscript
func _on_typing_finished() -> void:
    m_is_typing = false
    m_dialogue_label.visible_characters = -1   # 전체 표시
    _refresh_interaction_state(game_state.build_render_snapshot())
```

---

## 4. 입력 차단 / 활성화 정책

`_refresh_interaction_state()` 에서 `m_is_typing` 플래그를 함께 체크한다.

```
can_generate = library_ready AND backend_ready AND NOT turn_in_progress AND NOT is_typing
```

| 상태 | editable | mouse_filter | 결과 |
|------|----------|--------------|------|
| 타이핑 중 | false | IGNORE | 클릭 / 입력 완전 무반응 |
| 타이핑 완료 | true | STOP | 정상 입력 가능 |
| 턴 진행 중 | false | STOP | 시각 피드백은 있되 편집 불가 |

---

## 5. 입력창 세로 확장

### 5.1 기본 동작

- 기본 높이: **36px** (한 줄 바)
- 클릭(포커스) 시: **148px** 로 0.15초 애니메이션 확장
- 생성(submit) 후: **36px** 로 축소 + 포커스 해제

### 5.2 높이 상수

| 상수 | 값 |
|------|----|
| `INPUT_COLLAPSED_HEIGHT` | 36.0 |
| `INPUT_EXPANDED_HEIGHT` | 148.0 |

### 5.3 타이핑 중 클릭 차단

`focus_entered` 콜백에서 `m_is_typing` 이 참이면 즉시 `release_focus()` 를 호출한다.  
`mouse_filter = IGNORE` 와 이중으로 작동하여 확장이 일어나지 않는다.

```gdscript
func _on_input_focus_entered() -> void:
    if m_is_typing:
        m_input_edit.release_focus()
        return
    if not m_input_expanded:
        m_input_expanded = true
        _animate_input_height(INPUT_EXPANDED_HEIGHT)
```

---

## 6. 화자 이름 탭

`SpeakerName` (Label) 에 `content.speaker_name` 을 표시한다.  
비어 있으면 `"화자"` 로 fallback.

```gdscript
var speaker := _normalize_story_text(str(content.get("speaker_name", "")))
m_speaker_name_label.text = speaker if not speaker.is_empty() else "화자"
```

탭 너비는 내용에 따라 자동 늘어난다 (`SpeakerTab` 은 `PanelContainer`, fit_content 기본값 사용).

---

## 7. 캐릭터 슬롯 배치 변경

VnDialogLayer 가 화면 하단 38% 를 차지하므로, 캐릭터 슬롯의 하단 여백을 대폭 줄였다.

| 상수 | 변경 전 | 변경 후 |
|------|---------|---------|
| `SLOT_BOTTOM_MARGIN_RATIO` | 0.24 | 0.04 |
| bottom clamp 범위 | 180–320 px | 12–60 px |

이로써 캐릭터 이미지가 화면 아래까지 가득 채워지고, 대사창과 자연스럽게 오버랩된다.

---

## 8. 지원 캐릭터 수

슬롯 구조는 그대로 유지된다.

| 슬롯 | 위치 |
|------|------|
| `left` | 좌측 |
| `center` | 중앙 |
| `right` | 우측 |

기본 베이스는 `center` 슬롯 하나만 사용한다.  
2–3명 동시 출력은 `left` / `right` 슬롯을 함께 채우면 된다.  
백엔드 `direction.character_slots` 딕셔너리에서 슬롯별로 독립 제어한다.

---

## 9. @onready 노드 경로 변경 요약

| 변수 | 이전 경로 | 새 경로 |
|------|-----------|---------|
| `m_script_label` | `…/StoryScroll/StoryVBox/ScriptLabel` | ❌ 제거 |
| `m_story_scroll` | `…/DialoguePanel/Margin/VBox/StoryScroll` | ❌ 제거 |
| `m_speaker_name_label` | (신규) | `…/VnDialogLayer/SpeakerRow/SpeakerTab/SpeakerTabMargin/SpeakerName` |
| `m_dialogue_label` | (신규) | `…/VnDialogLayer/DialogBox/DialogMargin/DialogueLabel` |
| `m_player_input_panel` | (신규) | `…/VnDialogLayer/PlayerInputPanel` |
| `m_input_edit` | `…/DialoguePanel/Margin/VBox/InputEdit` | `…/VnDialogLayer/PlayerInputPanel/…/InputEdit` |
| `m_footer_status_label` | `…/DialoguePanel/Margin/VBox/FooterStatusLabel` | `…/VnDialogLayer/PlayerInputPanel/…/FooterStatusLabel` |
| `m_generate_button` 외 버튼들 | `…/DialoguePanel/…/ControlsRow/…` | `…/VnDialogLayer/PlayerInputPanel/…/ControlsRow/…` |

---

## 10. 확장 아이디어

- **타이핑 스킵**: 화면 클릭 시 남은 글자를 즉시 표시
- **타이핑 속도 설정**: SettingsManager 에 `typing_speed` 항목 추가
- **나레이션 / 대사 분리 표시**: narration 은 DialogBox 상단, dialogue 는 하단
- **입력창 포커스 아웃 시 축소**: `focus_exited` 에서 텍스트 비어 있으면 자동 축소
