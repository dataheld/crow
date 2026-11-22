// Screenshots of a shiny app, independent of timing,
// for crow's AppDriver (see local_app_driver()).

// Shows the end state of transitions and animations at once.
// bslib finishes some states only on `transitionend`,
// so transitions keep their duration, and thus their events.
function crowFreeze() {
  const style = document.createElement("style");
  style.textContent = `*, *::before, *::after {
    transition-delay: 0s !important;
    transition-timing-function: step-start !important;
    animation-delay: 0s !important;
    animation-duration: 0s !important;
    caret-color: transparent !important;
    scrollbar-width: none !important;
  }`;
  document.head.append(style);
  if (window.jQuery) jQuery.fx.off = true;
}

// Ends running transitions and animations,
// and waits until their event handlers and the layout have run,
// as with Popper's positioning of dropdown menus.
async function crowSettle() {
  for (const animation of document.getAnimations()) {
    if (isFinite(animation.effect?.getComputedTiming().endTime)) {
      animation.finish();
    }
  }
  await new Promise((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(resolve)),
  );
}

// The box around what the module in the element `id` paints,
// as chromote's `cliprect`: left, top, width and height of the document.
// It includes positioned descendants, such as open dropdown menus,
// but not what scroll containers hide.
function crowModuleBounds(id, notifications) {
  const stage = document.getElementById(id);
  if (!stage) return null;
  const elements = [...stage.querySelectorAll("*")];
  const panel = document.getElementById("shiny-notification-panel");
  if (notifications && panel) {
    elements.push(panel, ...panel.querySelectorAll("*"));
  }
  let box = crowVisibleRect(stage);
  for (const element of elements) {
    const [left, top, right, bottom] = crowVisibleRect(element);
    const shown = element.checkVisibility({
      opacityProperty: true,
      visibilityProperty: true,
    });
    if (shown && left < right && top < bottom) {
      box = [
        Math.min(box[0], left),
        Math.min(box[1], top),
        Math.max(box[2], right),
        Math.max(box[3], bottom),
      ];
    }
  }
  const [left, top, right, bottom] = box;
  return [left + scrollX, top + scrollY, right - left, bottom - top];
}

// The border box of `element`, without what its ancestors clip.
// An ancestor clips only elements whose containing block it contains:
// it does not clip absolutely positioned elements
// whose containing block is outside of it, nor fixed ones.
function crowVisibleRect(element) {
  let { left, top, right, bottom } = element.getBoundingClientRect();
  let position = getComputedStyle(element).position;
  for (
    let ancestor = element.parentElement;
    ancestor && ancestor !== document.body && position !== "fixed";
    ancestor = ancestor.parentElement
  ) {
    const style = getComputedStyle(ancestor);
    if (position === "absolute" && style.position === "static") continue;
    position = style.position;
    if (style.display === "inline" || style.display === "contents") continue;
    const outer = ancestor.getBoundingClientRect();
    const x = outer.left + ancestor.clientLeft;
    const y = outer.top + ancestor.clientTop;
    if (style.overflowX !== "visible") {
      left = Math.max(left, x);
      right = Math.min(right, x + ancestor.clientWidth);
    }
    if (style.overflowY !== "visible") {
      top = Math.max(top, y);
      bottom = Math.min(bottom, y + ancestor.clientHeight);
    }
  }
  // as the document clips what is hidden before its start,
  // such as the native input of shiny::fileInput()
  left = Math.max(left, -scrollX);
  top = Math.max(top, -scrollY);
  return [left, top, right, bottom];
}
