# DOMAIN: SwiftUI Gestures, Haptics & Interaction (touch, gesture composition, sensory feedback / CoreHaptics, context menus & menus, controls/concentric styling, text input & rich-text editing, focus, keyboard, search) — iOS 26 shipping, iOS 27 pre-GA.

## Orientation
 SwiftUI now has a complete declarative gesture stack — value-type gesture structs (TapGesture, LongPressGesture, DragGesture, MagnifyGesture, RotateGesture, SpatialTapGesture, plus RotateGesture3D on visionOS) composed with simultaneously/sequenced/exclusively and threaded through @GestureState (transient, auto-resets) vs @State (persistent). Haptics are modifier-first: reach for .sensoryFeedback(_:trigger:) (iOS 17+) for 95% of cases and only drop to CoreHaptics (CHHapticEngine/CHHapticPattern) for bespoke continuous/parametric haptics; UIFeedbackGenerator is legacy UIKit. The big iOS 26 craft surfaces are: rich-text editing with TextEditor bound to AttributedString + AttributedTextSelection (first-class native rich text); Liquid Glass search that floats and minimizes (searchToolbarBehavior, DefaultToolbarItem(.search), ToolbarSpacer); Writing Tools control via writingToolsBehavior; and concentric corner styling (ConcentricRectangle / .rect(corners:)) for controls that nest correctly inside Liquid Glass. iOS 27 (pre-GA, WWDC26) is incremental for this domain: universal drag-to-reorder (reorderable() / reorderContainer(for:)), swipeActions in any scroll container (swipeActionsContainer), and toolbarMinimizeBehavior(.onScrollDown). The cardinal pitfall remains gesture-vs-scroll conflict: prefer simultaneousGesture over highPriorityGesture inside scroll views, because iOS 18+ changed how custom gestures arbitrate against the system scroll gesture.

## Key facts
- [since iOS 17|high] .sensoryFeedback(_:trigger:) is the modern SwiftUI haptics API (iOS 17+, also macOS 14/watchOS 10/tvOS 17). SwiftUI watches the Equatable `trigger` value and plays the feedback whenever it changes — no generator object, no prepare() needed.
- [since iOS 17|high] Three .sensoryFeedback overloads: (1) fixed feedback + trigger; (2) feedback + trigger + condition closure `(oldValue, newValue) -> Bool` to gate playback; (3) trigger + closure `(oldValue, newValue) -> SensoryFeedback?` returning the feedback to play (return nil to skip), letting you pick the haptic dynamically from old/new state.
- [since iOS 17 (pathComplete iOS 17.5)|high] SensoryFeedback cases: .success, .warning, .error (notification-style), .selection, .impact (with flexibility:.soft/.solid/.rigid or weight:.light/.medium/.heavy and intensity:0...1), .increase / .decrease, .start / .stop, .alignment, .levelChange, .pathComplete (iOS 17.5+). .increase/.decrease/.alignment are most meaningful on watchOS/macOS; iPhone maps several to standard taps.
- [since iOS 17 (MagnifyGesture/RotateGesture renames)|high] Core gesture structs: TapGesture(count:), LongPressGesture(minimumDuration:maximumDistance:), DragGesture(minimumDistance:coordinateSpace:), MagnifyGesture (iOS 17+, replaced MagnificationGesture), RotateGesture (iOS 17+, replaced RotationGesture), SpatialTapGesture (gives tap location), and RotateGesture3D (visionOS).
- [deprecated iOS 17|high] MagnificationGesture and RotationGesture are deprecated in favor of MagnifyGesture and RotateGesture (iOS 17). The newer types expose richer values (e.g. RotateGesture.Value.rotation as Angle, velocity).
- [since iOS 13|high] Gesture composition: combine with the instance methods .simultaneously(with:), .sequenced(before:), .exclusively(before:) — or the wrapper types SimultaneousGesture, SequenceGesture, ExclusiveGesture. View-level shortcuts: .gesture(_:including:), .highPriorityGesture(_:), .simultaneousGesture(_:).
- [since iOS 13|high] @GestureState holds transient gesture state that AUTOMATICALLY resets to its initial value when the gesture ends/cancels; you mutate it only inside .updating(_:body:). Use plain @State (set in .onChanged/.onEnded) when you need the value to persist after the gesture finishes.
- [since iOS 16|high] onTapGesture(count:coordinateSpace:perform:) and onLongPressGesture support a count/coordinate space; SpatialTapGesture exposes the tap location in a named coordinate space via its Value.location.
- [iOS 18|medium] iOS 18 changed gesture arbitration with ScrollView: custom gestures now more aggressively block the system scroll gesture. Common fix is to switch from .highPriorityGesture() to .simultaneousGesture() so the scroll gesture still recognizes.
- [since iOS 18|high] onScrollGeometryChange(for:of:action:) (iOS 18+) reports content offset, content size, container size, content insets, and bounds via ScrollGeometry; the transform closure maps geometry to an Equatable and the action fires on change. Pairs with scrollPosition(_:) and onScrollVisibilityChange.
- [since iOS 17|high] scrollTransition(_:axis:transition:) (iOS 17+) animates a child relative to the scroll viewport. The closure receives content and a ScrollTransitionPhase with cases .topLeading, .identity, .bottomTrailing plus .value (-1...1) and .isIdentity — use it for scale/opacity/blur-on-scroll effects.
- [iOS 26|high] TextEditor gains first-class rich text in iOS 26: bind it to a $text of type AttributedString together with a $selection of type AttributedTextSelection. A native selection formatting menu (bold/italic/underline) appears automatically.
- [iOS 26|high] AttributedTextSelection (iOS 26) tracks cursor/selection as stable selection state (not raw indices). Apply formatting to just the selection with transformAttributes(in: &selection) { ... } so ranges stay valid as the string mutates.
- [since iOS 18 (Apple Intelligence)|high] writingToolsBehavior(_:) controls Apple Intelligence Writing Tools per text view: .automatic, .complete (full inline experience), .limited (suggestions only), .disabled. Pair with WritingToolsBehavior on TextField/TextEditor.
- [iOS 26|high] iOS 26 Liquid Glass search: searchToolbarBehavior(.minimize) collapses the search field into a toolbar button; the system may auto-apply based on device size / toolbar item count. DefaultToolbarItem(kind: .search) reserves the search slot and ToolbarSpacer(_:placement:) controls spacing so search can sit in the bottom bar on iPhone.
- [since iOS 16 (presentation behaviors iOS 17.1)|high] Search building blocks: searchable(text:tokens:suggestedTokens:placement:prompt:) for tokenized search, searchScopes(_:scopes:) for a scope picker (segmented on iOS), @Environment(\.isSearching) and dismissSearch to read/cancel search, and searchFocused/$searchText for focus. searchPresentationToolbarBehavior(.avoidHidingContent) keeps content visible while searching.
- [since iOS 16|high] contextMenu(menuItems:preview:) shows a custom preview View next to the menu; contextMenu(forSelectionType:menu:primaryAction:) supports multi-select context menus in List/Table with a primary (tap/double-tap) action.
- [since iOS 16|high] Menu with a primaryAction: closure makes a tap run the primary action while a long-press opens the menu. menuIndicator(.hidden) hides the chevron; menuActionDismissBehavior(.disabled) keeps the menu open after an action.
- [iOS 26|high] ConcentricRectangle (iOS 26) and Shape.rect(corners:) with a concentric corner style auto-derive inner corner radii so controls nest correctly inside Liquid Glass containers; use ContainerRelativeShape / concentric styling for buttons and cards that must match the enclosing capsule.
- [since iOS 18|high] ControlWidget (Control Center / Lock Screen / Action button controls) is authored in SwiftUI via WidgetKit (ControlWidgetButton, ControlWidgetToggle, ControlWidgetTemplate). Introduced iOS 18, refined for Liquid Glass in iOS 26.
- [iOS 27 (pre-GA, may change)|medium] iOS 27 (pre-GA, WWDC26): universal drag-to-reorder via reorderable() on dynamic content + reorderContainer(for:) scope — works in LazyVStack/LazyVGrid/custom layouts, not just List; SwiftUI handles drag preview, placeholder, and drop animation. Reordering also reaches watchOS.
- [iOS 27 (pre-GA, may change)|medium] iOS 27 (pre-GA): swipeActions extend beyond List to any scroll container, coordinated by a new swipeActionsContainer() modifier on ScrollView; toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar) hides chrome on scroll; CrossFadeNavigationTransition and AnyNavigationTransition (runtime-selectable navigation transitions) are added.
- [since iOS 15 (scrollDismissesKeyboard iOS 16)|high] Keyboard avoidance is automatic in SwiftUI; opt out per-view with ignoresSafeArea(.keyboard). Use @FocusState (+ focused(_:)/focused(_:equals:)) to drive focus, submitLabel(_:) to set the return-key label, and onSubmit(of:_:) to react to submission. scrollDismissesKeyboard(_:) controls keyboard dismissal on scroll.

## APIs
- `sensoryFeedback(_:trigger:)` (modifier; iOS 17+) — Plus condition-closure and feedback-returning-closure overloads.
- `SensoryFeedback` (type; iOS 17+) — Cases: success/warning/error/selection/impact(flexibility:intensity:)/impact(weight:intensity:)/increase/decrease/start/stop/alignment/levelChange/pathComplete.
- `CHHapticEngine` (type; iOS 13+ (CoreHaptics)) — Custom/continuous haptics; check capabilitiesForHardware().supportsHaptics.
- `CHHapticPattern / CHHapticEvent` (type; iOS 13+) — Build parametric haptic patterns (intensity, sharpness).
- `UIFeedbackGenerator` (type; iOS 10+ (legacy)) — UIKit impact/notification/selection generators; superseded by .sensoryFeedback in SwiftUI.
- `TapGesture` (type; iOS 13+) — count: for multi-tap.
- `SpatialTapGesture` (type; iOS 16+) — Value.location gives tap point in a coordinate space.
- `LongPressGesture` (type; iOS 13+) — minimumDuration:, maximumDistance:.
- `DragGesture` (type; iOS 13+) — minimumDistance:, coordinateSpace:; Value has translation/location/velocity/predictedEndTranslation.
- `MagnifyGesture` (type; iOS 17+) — Replaces MagnificationGesture.
- `RotateGesture` (type; iOS 17+) — Replaces RotationGesture; Value.rotation is Angle.
- `RotateGesture3D` (type; visionOS 1+) — 3D rotation.
- `SimultaneousGesture / SequenceGesture / ExclusiveGesture` (type; iOS 13+) — Or instance methods .simultaneously(with:)/.sequenced(before:)/.exclusively(before:).
- `@GestureState` (property wrapper; iOS 13+) — Transient, auto-resetting; mutate in .updating(_:body:).
- `highPriorityGesture(_:) / simultaneousGesture(_:) / gesture(_:including:)` (modifier; iOS 13+) — GestureMask via including:.
- `onScrollGeometryChange(for:of:action:)` (modifier; iOS 18+) — ScrollGeometry: contentOffset/contentSize/containerSize/contentInsets/bounds.
- `scrollTransition(_:axis:transition:)` (modifier; iOS 17+) — ScrollTransitionPhase: topLeading/identity/bottomTrailing, .value, .isIdentity.
- `scrollPosition(_:) / scrollTargetLayout() / scrollTargetBehavior(_:)` (modifier; iOS 17+) — Programmatic scroll + paging/snap.
- `scrollDismissesKeyboard(_:)` (modifier; iOS 16+) — .interactively/.immediately/.automatic/.never.
- `TextEditor(text:selection:)` (type; iOS 26 (AttributedString overload)) — Rich text with AttributedString + AttributedTextSelection.
- `AttributedTextSelection` (type; iOS 26) — Stable text selection state.
- `AttributedString.transformAttributes(in:)` (modifier; iOS 26) — Mutate attributes on the current selection safely.
- `writingToolsBehavior(_:) / WritingToolsBehavior` (modifier; iOS 18+) — .automatic/.complete/.limited/.disabled.
- `@FocusState / focused(_:) / focused(_:equals:)` (property wrapper; iOS 15+) — Declarative focus; set nil to dismiss keyboard.
- `submitLabel(_:) / onSubmit(of:_:)` (modifier; iOS 15+) — Return-key label + submission handling.
- `searchable(text:tokens:suggestedTokens:placement:prompt:)` (modifier; iOS 16+ (tokens iOS 16)) — Tokenized search.
- `searchScopes(_:scopes:)` (modifier; iOS 16+) — Scope picker (segmented on iOS).
- `searchToolbarBehavior(_:)` (modifier; iOS 26) — .minimize collapses search into a toolbar button.
- `DefaultToolbarItem(kind:placement:)` (type; iOS 26) — kind: .search reserves search slot.
- `ToolbarSpacer` (type; iOS 26) — Flexible/fixed spacing between toolbar groups.
- `searchPresentationToolbarBehavior(_:)` (modifier; iOS 17.1+) — .avoidHidingContent.
- `isSearching / dismissSearch` (type; iOS 15+) — Environment value + action to read/cancel search.
- `contextMenu(menuItems:preview:)` (modifier; iOS 16+) — Custom preview view.
- `contextMenu(forSelectionType:menu:primaryAction:)` (modifier; iOS 16+) — Multi-select menus in List/Table.
- `Menu(...) primaryAction:` (type; iOS 16+) — Tap = primary action, long-press = menu.
- `menuIndicator(_:) / menuActionDismissBehavior(_:)` (modifier; iOS 15+ / iOS 16.4+) — .hidden indicator; .disabled keeps menu open.
- `ConcentricRectangle / Shape.rect(corners:)` (type; iOS 26) — Concentric corner styling for nested controls.
- `ControlWidget / ControlWidgetButton / ControlWidgetToggle` (type; iOS 18+) — Control Center / Action-button controls in SwiftUI/WidgetKit.
- `reorderable() / reorderContainer(for:)` (modifier; iOS 27 (pre-GA)) — Universal drag-to-reorder in any container.
- `swipeActionsContainer()` (modifier; iOS 27 (pre-GA)) — swipeActions in any scroll container.
- `toolbarMinimizeBehavior(_:for:)` (modifier; iOS 27 (pre-GA)) — .onScrollDown auto-hides chrome on scroll.

## Patterns

### Modern haptics with .sensoryFeedback  — Any standard tactile cue (toggle, success, selection change). Default choice over UIFeedbackGenerator and CoreHaptics.
Trigger must be Equatable; feedback fires on change. Prefer the closure overload when the haptic depends on direction of change. No prepare() needed — SwiftUI manages the generator.
```swift
@State private var liked = false

Image(systemName: liked ? "heart.fill" : "heart")
    .onTapGesture { liked.toggle() }
    // Pick the haptic from the new value:
    .sensoryFeedback(trigger: liked) { _, isLiked in
        isLiked ? .success : .impact(flexibility: .soft, intensity: 0.5)
    }
```

### Custom continuous haptic with CoreHaptics  — Bespoke textures, parametric/continuous haptics, or audio-synced haptics that .sensoryFeedback can't express.
Always gate on capabilitiesForHardware().supportsHaptics. Restart the engine on .stoppedHandler / app-foreground. This is the only path for continuous/curve-based haptics.
```swift
import CoreHaptics

final class Haptics {
    private var engine: CHHapticEngine?
    func start() { engine = try? CHHapticEngine(); try? engine?.start() }
    func buzz() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let event = CHHapticEvent(eventType: .hapticContinuous,
            parameters: [.init(parameterID: .hapticIntensity, value: 0.8),
                         .init(parameterID: .hapticSharpness, value: 0.4)],
            relativeTime: 0, duration: 0.4)
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        try engine?.makePlayer(with: pattern).start(atTime: 0)
    }
}
```

### @GestureState drag that snaps back  — Transient drag offset/long-press state that should auto-reset when the finger lifts.
dragOffset resets to .zero automatically on end/cancel — no manual cleanup. Use .onEnded for anything that must persist (the @GestureState is already gone by then).
```swift
@GestureState private var dragOffset: CGSize = .zero

card
  .offset(dragOffset)
  .gesture(
    DragGesture()
      .updating($dragOffset) { value, state, _ in state = value.translation }
      .onEnded { value in commitIfPastThreshold(value.translation) }
  )
```

### Composing gestures: long-press then drag  — Drag-to-reorder-style interactions where the drag must begin only after a press is recognized.
Use .sequenced(before:) for press-then-drag, .simultaneously(with:) for pinch+rotate, .exclusively(before:) when only one of two should win. On iOS 27 prefer the built-in reorderable()/reorderContainer(for:) instead of hand-rolling this for reordering.
```swift
let press = LongPressGesture(minimumDuration: 0.4)
let drag = DragGesture()
view.gesture(
  press.sequenced(before: drag)
       .onEnded { value in /* handle */ }
)
```

### Avoiding gesture/scroll conflicts  — A custom gesture lives inside a ScrollView and scrolling stops working (iOS 18+).
highPriorityGesture starves the system scroll gesture on iOS 18+. Use simultaneousGesture so both recognize, and add minimumDistance/minimumDuration so the custom gesture doesn't fire on a scroll flick.
```swift
ScrollView {
  content
    .simultaneousGesture(           // not highPriorityGesture
      LongPressGesture().onEnded { _ in showMenu() }
    )
}
```

### Scroll-driven visual effects  — Cards that scale/fade as they enter/leave the viewport, or reacting to scroll offset.
phase.value runs -1 (topLeading) → 0 (identity) → 1 (bottomTrailing) for interpolating. onScrollGeometryChange is the supported way to read offset (don't abuse GeometryReader/PreferenceKey).
```swift
ForEach(items) { item in
  CardView(item)
    .scrollTransition { content, phase in
      content
        .opacity(phase.isIdentity ? 1 : 0.3)
        .scaleEffect(phase.isIdentity ? 1 : 0.85)
        .blur(radius: phase.isIdentity ? 0 : 4)
    }
}
.scrollTargetLayout()
// React to raw offset:
.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
    headerCollapsed = y > 80
}
```

### Native rich-text editing (iOS 26)  — In-app rich text: notes, comments, descriptions with bold/italic/color.
iOS 26 only. Bind both text (AttributedString) and selection (AttributedTextSelection). transformAttributes(in:) mutates only the selected run and keeps the selection valid. A native format menu also appears on selection.
```swift
@State private var text = AttributedString("Edit me")
@State private var selection = AttributedTextSelection()

TextEditor(text: $text, selection: $selection)
  .toolbar {
    Button("Bold") {
      text.transformAttributes(in: &selection) { container in
        let isBold = container.font?.weight == .bold
        container.font = (container.font ?? .body).weight(isBold ? .regular : .bold)
      }
    }
  }
```

### Focus, submit label, keyboard  — Multi-field forms; moving focus on return; dismissing the keyboard.
@FocusState drives focus declaratively; set it to nil to dismiss the keyboard. Keyboard avoidance is automatic — only add ignoresSafeArea(.keyboard) to opt out.
```swift
enum Field { case email, password }
@FocusState private var focus: Field?

TextField("Email", text: $email)
  .focused($focus, equals: .email)
  .submitLabel(.next)
  .onSubmit { focus = .password }
SecureField("Password", text: $password)
  .focused($focus, equals: .password)
  .submitLabel(.go)
  .onSubmit { logIn() }
// elsewhere:
ScrollView { form }.scrollDismissesKeyboard(.interactively)
```

### Liquid Glass search with tokens & scopes (iOS 26)  — Filtered/tokenized search that adapts to iPhone vs iPad placement.
searchToolbarBehavior(.minimize) collapses search into a toolbar button under Liquid Glass. Use DefaultToolbarItem(kind: .search) + ToolbarSpacer to control bottom-bar placement on iPhone. Read @Environment(\.isSearching) and call dismissSearch to cancel.
```swift
@State private var query = ""
@State private var tokens: [Tag] = []
@State private var scope: Scope = .all

NavigationStack { list }
  .searchable(text: $query, tokens: $tokens) { token in Text(token.name) }
  .searchScopes($scope) { ForEach(Scope.allCases) { Text($0.title).tag($0) } }
  .searchToolbarBehavior(.minimize)
```

### Context menu with preview + multi-select  — Rich long-press menus, especially in lists/tables.
preview: renders any view in the rounded preview card. forSelectionType: gives true multi-select menus; primaryAction handles tap/double-tap.
```swift
row.contextMenu {
  Button("Share", systemImage: "square.and.arrow.up") { share() }
  Button("Delete", systemImage: "trash", role: .destructive) { delete() }
} preview: {
  DetailPreview(item)   // custom preview view
}

// Multi-select in a List:
List(selection: $selection) { /* rows */ }
  .contextMenu(forSelectionType: Item.ID.self) { ids in
    Button("Delete \(ids.count)", role: .destructive) { delete(ids) }
  } primaryAction: { ids in open(ids) }
```

## Pitfalls
- highPriorityGesture inside a ScrollView starves the system scroll gesture on iOS 18+ — scrolling silently stops. Use simultaneousGesture and set minimumDistance/minimumDuration so the custom gesture doesn't steal scroll flicks.
- @GestureState is read-only outside .updating() and auto-resets the instant the gesture ends — if you read it in .onEnded it's already back to the initial value. Persist final state in a separate @State.
- DragGesture defaults to minimumDistance: 10; a TapGesture and DragGesture on the same view can conflict. Use exclusively/sequenced composition rather than stacking two .gesture modifiers and hoping for the best.
- .sensoryFeedback fires only when the trigger value actually CHANGES. Re-assigning the same value (e.g. true → true) plays nothing; toggle a counter or Bool, or use the condition overload.
- Many SensoryFeedback cases (.increase, .decrease, .alignment, .levelChange) are no-ops or remapped on iPhone — they're meaningful mainly on watchOS/macOS. Don't rely on them for iPhone-only UX.
- CoreHaptics silently does nothing on devices/simulators without a Taptic Engine — always guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, and restart the engine after it's stopped (interruptions, backgrounding).
- UIFeedbackGenerator (UIImpactFeedbackGenerator etc.) is the legacy UIKit path; in SwiftUI prefer .sensoryFeedback. If you must use it, call prepare() before impactOccurred() or latency is noticeable.
- Rich-text TextEditor binding to AttributedString + AttributedTextSelection is iOS 26-only — gate with #available; on earlier OSes TextEditor only takes a plain String.
- MagnificationGesture / RotationGesture still compile but are deprecated; new code should use MagnifyGesture / RotateGesture, whose Value types differ (e.g. RotateGesture.Value.rotation is an Angle).
- Reading scroll offset via GeometryReader+PreferenceKey is fragile and causes layout passes; use onScrollGeometryChange(for:of:action:) (iOS 18+) instead.
- scrollTransition effects only animate views inside the scroll content that participate in the scroll target layout; forgetting scrollTargetLayout()/scrollTargetBehavior can make transitions look wrong at edges.
- writingToolsBehavior(.disabled) is needed where Writing Tools would corrupt structured input (code editors, formatted fields) — otherwise Apple Intelligence may rewrite content the user didn't intend.

## iOS 26 changes
- TextEditor gains first-class AttributedString rich-text editing with AttributedTextSelection and transformAttributes(in:); a native selection-formatting menu appears automatically.
- Liquid Glass search: searchToolbarBehavior(.minimize) collapses the field into a toolbar button; DefaultToolbarItem(kind:.search) and ToolbarSpacer reserve/space the search slot; search floats to top-trailing on iPad and bottom on iPhone.
- ConcentricRectangle shape and Shape.rect(corners:) with concentric corner style auto-derive nested inner corner radii so controls nest correctly inside Liquid Glass capsules/containers.
- ControlWidget (Control Center / Action button) styling refined for Liquid Glass; SwiftUI WidgetKit controls (ControlWidgetButton/Toggle) adopt the new material.

## iOS 27 preview (pre-GA)
- Universal drag-to-reorder: reorderable() on dynamic content + reorderContainer(for:) scope, working in LazyVStack/LazyVGrid/custom layouts (not just List); SwiftUI provides drag preview, placeholder, drop animation. Reordering also reaches watchOS. | Developer beta, exact signatures may change before GA.
- swipeActions usable in any scroll container, coordinated by swipeActionsContainer() on ScrollView (previously List-only). | Pre-GA; name/behavior may change.
- toolbarMinimizeBehavior(.onScrollDown, for: .navigationBar) auto-hides chrome on scroll; toolbar visibilityPriority(_:) keeps key groups visible when space is tight. | Pre-GA.
- CrossFadeNavigationTransition (source-less cross-fade) and AnyNavigationTransition (runtime-selectable navigation transition type eraser) added. | Pre-GA; affects navigation interaction feel.

## Deprecations
- MagnificationGesture → MagnifyGesture (iOS 17)
- RotationGesture → RotateGesture (iOS 17)
- UIFeedbackGenerator / UIImpactFeedbackGenerator / UINotificationFeedbackGenerator / UISelectionFeedbackGenerator (UIKit) → .sensoryFeedback(_:trigger:) in SwiftUI (iOS 17)
- Manual GeometryReader + PreferenceKey scroll-offset tracking → onScrollGeometryChange / scrollPosition (iOS 18)
- Hand-rolled LongPressGesture.sequenced(before: DragGesture) reorder logic → reorderable() / reorderContainer(for:) (iOS 27, pre-GA)
- Plain-String-only TextEditor for rich text (had to bridge to UITextView) → TextEditor(text: AttributedString, selection: AttributedTextSelection) (iOS 26)

## Uncertainties
- Exact iOS 27 signatures for reorderable(), reorderContainer(for:), swipeActionsContainer(), toolbarMinimizeBehavior, CrossFadeNavigationTransition, AnyNavigationTransition come from secondary WWDC26 write-ups (dev.to, nilcoalescing); could not fully verify against developer.apple.com docs (JS-rendered / pre-GA pages were thin on fetch). Treat as pre-GA, may change before iOS 27 GA.
- The full SensoryFeedback case list and exact iOS introduction of .pathComplete were corroborated from secondary sources (createwithswift, Apple doc index) but the per-case iOS-availability matrix on developer.apple.com was not fetched line-by-line.
- Whether searchToolbarBehavior is spelled searchToolbarBehavior vs searchPresentationToolbarBehavior in all contexts: iOS 26 added searchToolbarBehavior(.minimize); the older searchPresentationToolbarBehavior(_:) (iOS 17.1) still exists. Both confirmed but they are distinct APIs.
- iOS 18-era gesture/scroll arbitration change is documented via Fatbobman/forums rather than an explicit Apple changelog; the simultaneousGesture-over-highPriorityGesture guidance is empirically reported, not a formal Apple deprecation.

## Sources
- sensoryFeedback(_:trigger:) — Apple Developer Documentation: https://developer.apple.com/documentation/SwiftUI/View/sensoryFeedback(_:trigger:)
- SensoryFeedback — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/sensoryfeedback
- Providing feedback with the sensory feedback modifier — Create with Swift: https://www.createwithswift.com/providing-feedback-sensory-feedback-modifier/
- Gesture — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/gesture
- How to use gestures in SwiftUI — Hacking with Swift: https://www.hackingwithswift.com/books/ios-swiftui/how-to-use-gestures-in-swiftui
- Customizing Gestures in SwiftUI — Fatbobman: https://fatbobman.com/en/posts/swiftuigesture/
- onScrollGeometryChange(for:of:action:) — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)
- scrollTransition(_:axis:transition:) — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/scrolltransition(_:axis:transition:)
- ScrollTransitionPhase.topLeading — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/scrolltransitionphase/topleading
- Using rich text in the TextEditor with SwiftUI — Create with Swift: https://www.createwithswift.com/using-rich-text-in-the-texteditor-with-swiftui/
- How to use rich text editing with TextView and AttributedString — Hacking with Swift: https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-rich-text-editing-with-textview-and-attributedstring
- WritingToolsBehavior — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/writingtoolsbehavior
- SwiftUI Search Enhancements in iOS and iPadOS 26 — Nil Coalescing: https://nilcoalescing.com/blog/SwiftUISearchEnhancementsIniOSAndiPadOS26/
- searchPresentationToolbarBehavior(_:) — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/searchpresentationtoolbarbehavior(_:)
- contextMenu(menuItems:preview:) — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/view/contextmenu(menuitems:preview:)
- MenuActionDismissBehavior — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/menuactiondismissbehavior
- Corner concentricity in SwiftUI on iOS 26 — Nil Coalescing: https://nilcoalescing.com/blog/ConcentricRectangleInSwiftUI/
- ControlWidget — Apple Developer Documentation: https://developer.apple.com/documentation/swiftui/controlwidget
- New SwiftUI APIs for reordering and drag and drop on iOS 27 — Nil Coalescing: https://nilcoalescing.com/blog/NewSwiftUIAPIsForReorderingAndDragAndDropOniOS27/
- WWDC26: What's New in SwiftUI — A Developer's Breakdown (dev.to): https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333
- WWDC26 SwiftUI guide — Apple Developer: https://developer.apple.com/wwdc26/guides/swiftui/
