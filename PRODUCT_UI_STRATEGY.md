# Product UI Strategy

## Product goal

Build a practical Chinese-Vietnamese translation app that also helps users learn and chat.

The app should feel:

- fast like a utility
- clear like a professional tool
- memorable through a light modem and pixel visual identity
- usable on everyday Android phones in China

## Core product positioning

This app is not only a translator.

It should combine:

- translation
- conversation support
- image text extraction
- chat assistance
- vocabulary learning

The key difference is that translation and learning should reinforce each other instead of living in separate tabs with weak connection.

## UX principles

- Home screen should focus on one main task at a time.
- High-frequency actions should stay in thumb reach.
- Rare settings and secondary tools should move out of the primary navigation.
- Translation results should immediately expose next actions: copy, speak, favorite, insert into chat, save to study.
- Learning content should be generated from real translation history.
- Visual style can be distinctive, but readability must stay modern.

## Recommended information architecture

Replace the current flat tool-first navigation with a task-first structure.

### 1. Translate

Main entry for text translation.

Layout:

- top modem status bar
- language direction switch
- large input area
- translated result card
- action row
- learning expansion area

Primary actions:

- paste
- clear
- speak source
- speak result
- copy result
- favorite
- save to phrasebook

Secondary sections below result:

- alternate wording
- dictionary meaning
- example sentence
- slang or usage note

### 2. Conversation

For face-to-face speaking.

Layout:

- fixed language pair header
- two stacked speech panels
- single prominent microphone action
- transcript history

Primary actions:

- hold to speak
- switch language direction
- replay translation
- copy each line

### 3. Camera

For signs, menus, screenshots, and app pages.

Layout:

- full camera preview
- bottom capture controls
- result overlay after OCR

Primary actions:

- live scan
- capture photo
- import screenshot
- copy extracted text
- translate extracted text
- save words

### 4. Chat Assist

Dedicated helper for messaging scenarios like Zalo.

Layout:

- quick translation composer
- clipboard monitor section
- screenshot OCR section
- insert-ready translated text panel

Primary actions:

- translate what I type
- copy translated message
- paste from clipboard
- translate screenshot text
- open floating helper guide

### 5. Learn

Learning should be driven by real usage, not isolated lists.

Sections:

- saved words
- saved phrases
- common scenarios
- slang
- review cards

## What should leave the main navigation

Move these out of the current primary tab bar:

- dictionary as a full top-level tab
- slang as a full top-level tab
- settings as a floating button

They should become:

- dictionary and slang inside Learn or inside result details
- settings inside a top-right entry or profile/tools page

## Mobile layout guidance

### Translate page

- Keep one vertical column.
- Keep the input card visible first.
- Show result immediately below input.
- Put the most important action row directly under the result.
- Keep secondary learning cards collapsed by default.

### Bottom navigation

Recommended tabs:

- Translate
- Conversation
- Camera
- Chat Assist
- Learn

Avoid more than five tabs.

### Thumb-zone priorities

Bottom area should contain:

- translate
- mic
- copy
- favorite
- insert into chat

Top area should contain:

- language switch
- status
- settings

## Visual direction

Use a practical retro-tech look, not a full nostalgia parody.

### Design mix

- Google Translate: speed and clarity
- DeepL: clean hierarchy and writing confidence
- Papago: multimodal translation and chat helper inspiration
- HelloTalk: translation connected to learning and messaging
- 98.css / XP.css / os-gui / terminal.css: structural retro UI cues

### Style rules

- body text must stay highly readable
- pixel feel should appear in headings, labels, icons, borders, and indicators
- avoid full-screen CRT noise or heavy distortion
- use 1px hard borders and subtle inset panels
- keep spacing modern even if the components feel retro

### Suggested palette

- shell: warm off-white
- ink: deep green
- accent: cyan-blue
- alert: amber
- success: phosphor green

## Modem and pixel elements to integrate

Use lightly:

- status LEDs
- terminal-style badges
- segmented progress bars
- pixel-bordered cards
- tiny signal labels like ONLINE, OFFLINE, OCR, MIC

Do not overuse:

- heavy scanlines
- full monochrome screens
- noisy backgrounds
- tiny bitmap body fonts

## Cross-app translation capability

### Current project state

The current app can translate only inside itself.

It does not currently include:

- Android accessibility service
- overlay translation helper
- input method editor
- cross-app text capture
- automatic message insertion

So right now it cannot directly read Zalo content, translate in-app webpage text inside Zalo, or translate and send replies automatically.

### Recommended rollout

#### Phase 1: Safe and practical

- share text into the app
- clipboard translate
- screenshot OCR translate
- quick copy back to chat

#### Phase 2: Chat helper

- floating helper bubble
- in-app quick translate panel
- one-tap copy translated message

#### Phase 3: Input assistance

- custom translation keyboard
- translate Chinese to Vietnamese inside the input flow
- insert translated text into the current text field

### Not recommended

Avoid automatic sending on behalf of the user.

Reasons:

- high risk of mistakes
- bad compatibility across chat apps
- possible platform policy issues
- poor trust when translation quality varies

Preferred behavior:

- translate
- preview
- insert
- user taps send

## Feature requirements to add

- translation history
- favorites and phrasebook
- tone presets: literal, natural, polite
- scenario shortcuts: travel, dating, work, shopping
- OCR from screenshots
- clipboard helper
- chat insert flow
- offline model status
- vocabulary extracted from translation history

## Build priorities

1. Stabilize Android release and emulator workflow.
2. Redesign Translate, Conversation, and Learn screens under one visual system.
3. Add Chat Assist as a real product mode.
4. Add screenshot OCR and clipboard flow before attempting deeper cross-app integration.
5. Explore custom keyboard support only after the core translator is stable.
