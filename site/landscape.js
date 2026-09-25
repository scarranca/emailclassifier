/* Cove's original point-cloud artwork, brought to life on the GPU. */
(() => {
  const sections = [...document.querySelectorAll('.hero, .closing')];
  if (!sections.length) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const touch = matchMedia('(pointer: coarse)');
  let paused = false;
  try { paused = sessionStorage.getItem('cove-motion-paused') === 'true'; } catch {}
  let frame = 0;
  let previous = 0;
  let time = 0;
  let lastDraw = 0;
  const scenes = [];

  const vertexSource = `
    attribute vec2 a_position;
    varying vec2 v_uv;
    void main() {
      v_uv = a_position * .5 + .5;
      gl_Position = vec4(a_position, 0., 1.);
    }`;
  const fragmentSource = `
    #ifdef GL_FRAGMENT_PRECISION_HIGH
    precision highp float;
    #else
    precision mediump float;
    #endif
    varying vec2 v_uv;
    uniform sampler2D u_image;
    uniform vec2 u_cover;
    uniform vec2 u_pointer;
    uniform vec2 u_impulse;
    uniform float u_aspect;
    uniform float u_time;
    uniform float u_hover;
    uniform float u_age;
    uniform float u_pan;
    uniform float u_strength;
    void main() {
      vec2 screen = vec2(v_uv.x, 1. - v_uv.y);
      vec2 uv = (screen - .5) * u_cover + vec2(u_pan, .5);
      float depth = smoothstep(.12, 1., screen.y);
      float t = u_time;
      // Broad swells and smaller currents keep the existing terrain intact.
      vec2 flow = vec2(
        sin(uv.y * 10. + uv.x * 3. - t * .32) * .011 + sin(uv.y * 24. + t * .21) * .003,
        sin(uv.x * 9. - uv.y * 5. + t * .38) * .013 + cos(uv.x * 18. + t * .24) * .004
      ) * (.35 + depth * .65);
      vec2 delta = screen - u_pointer;
      delta.x *= u_aspect;
      float distance = length(delta);
      float influence = exp(-distance * distance * 9.) * u_hover;
      vec2 direction = delta / max(distance, .001);
      direction.x /= u_aspect;
      flow += direction * influence * .016;
      // A single expanding ring follows a tap; no flashing or repeated bursts.
      vec2 ringDelta = screen - u_impulse;
      ringDelta.x *= u_aspect;
      float ringDistance = length(ringDelta);
      float ring = sin(ringDistance * 27. - u_age * 3.8)
        * exp(-pow((ringDistance - u_age * .20) * 6., 2.))
        * exp(-u_age * .85) * step(0., u_age);
      vec2 ringDirection = ringDelta / max(ringDistance, .001);
      ringDirection.x /= u_aspect;
      flow += ringDirection * ring * .015;
      uv += flow * u_strength;
      // A small camera drift gives the foreground a sense of depth.
      uv += (u_pointer - .5) * .005 * u_hover * depth;
      uv = (uv - .5) * .965 + .5;
      vec3 color = texture2D(u_image, vec2(clamp(uv.x, .001, .999), 1. - clamp(uv.y, .001, .999))).rgb;
      float light = .97 + .075 * sin(uv.x * 5. + uv.y * 7. - t * .35);
      light += influence * .26 + max(0., ring) * .08;
      gl_FragColor = vec4(color * light, 1.);
    }`;

  function compile(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      gl.deleteShader(shader);
      throw new Error('Landscape shader unavailable');
    }
    return shader;
  }

  function createScene(section, artwork) {
    const canvas = document.createElement('canvas');
    canvas.className = 'landscape-canvas';
    canvas.setAttribute('aria-hidden', 'true');
    const gl = canvas.getContext('webgl', { alpha: false, antialias: false, depth: false, stencil: false, powerPreference: 'low-power' });
    if (!gl) return;
    let program;
    try {
      program = gl.createProgram();
      const vertex = compile(gl, gl.VERTEX_SHADER, vertexSource);
      const fragment = compile(gl, gl.FRAGMENT_SHADER, fragmentSource);
      gl.attachShader(program, vertex);
      gl.attachShader(program, fragment);
      gl.linkProgram(program);
      gl.deleteShader(vertex);
      gl.deleteShader(fragment);
      if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error('Landscape unavailable');
    } catch {
      if (program) gl.deleteProgram(program);
      return;
    }
    gl.useProgram(program);
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    const attribute = gl.getAttribLocation(program, 'a_position');
    gl.enableVertexAttribArray(attribute);
    gl.vertexAttribPointer(attribute, 2, gl.FLOAT, false, 0, 0);
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, artwork);
    const uniform = Object.fromEntries(['cover', 'pointer', 'impulse', 'aspect', 'time', 'hover', 'age', 'pan', 'strength'].map(name => [name, gl.getUniformLocation(program, `u_${name}`)]));
    const scene = { section, canvas, gl, uniform, visible: false, lost: false, x: .5, y: .6, targetX: .5, targetY: .6, hover: 0, targetHover: 0, impulseX: .5, impulseY: .6, impulseTime: -100, width: 0, height: 0 };
    const control = document.createElement('button');
    control.className = 'landscape-control';
    control.type = 'button';
    control.addEventListener('click', () => {
      paused = !paused;
      try { sessionStorage.setItem('cove-motion-paused', String(paused)); } catch {}
      sync();
    });
    scene.control = control;
    section.prepend(canvas);
    section.append(control);
    const resize = () => {
      if (scene.lost) return;
      scene.width = section.clientWidth;
      scene.height = section.clientHeight;
      const density = Math.min(devicePixelRatio || 1, touch.matches ? 1 : 1.5, Math.sqrt(1800000 / (scene.width * scene.height)));
      canvas.width = Math.round(scene.width * density);
      canvas.height = Math.round(scene.height * density);
      gl.viewport(0, 0, canvas.width, canvas.height);
      const aspect = scene.width / scene.height;
      const imageAspect = artwork.naturalWidth / artwork.naturalHeight;
      const coverX = Math.min(1, aspect / imageAspect);
      const coverY = Math.min(1, imageAspect / aspect);
      gl.uniform2f(uniform.cover, coverX, coverY);
      gl.uniform1f(uniform.aspect, aspect);
      gl.uniform1f(uniform.pan, scene.width <= 700 ? .6 - coverX * .1 : .5);
      gl.uniform1f(uniform.strength, section.classList.contains('closing') ? .65 : 1.);
      if (!scene.lost) draw(scene);
    };
    new ResizeObserver(resize).observe(section);
    const locate = event => {
      const rect = section.getBoundingClientRect();
      scene.targetX = (event.clientX - rect.left) / rect.width;
      scene.targetY = (event.clientY - rect.top) / rect.height;
    };
    section.addEventListener('pointermove', event => {
      if (paused || reduced.matches || event.pointerType === 'touch') return;
      locate(event);
      scene.targetHover = 1;
    }, { passive: true });
    section.addEventListener('pointerleave', () => { scene.targetHover = 0; });
    section.addEventListener('pointerdown', event => {
      if (paused || reduced.matches || event.target.closest('a, button')) return;
      locate(event);
      scene.impulseX = scene.targetX;
      scene.impulseY = scene.targetY;
      scene.impulseTime = time;
    }, { passive: true });
    canvas.addEventListener('webglcontextlost', event => {
      event.preventDefault();
      scene.lost = true;
      section.classList.remove('motion-ready');
      control.hidden = true;
      sync();
    });
    scenes.push(scene);
    observer.observe(section);
    resize();
    section.classList.add('motion-ready');
  }

  function draw(scene) {
    const { gl, uniform } = scene;
    gl.uniform1f(uniform.time, time);
    gl.uniform2f(uniform.pointer, scene.x, scene.y);
    gl.uniform1f(uniform.hover, scene.hover);
    gl.uniform2f(uniform.impulse, scene.impulseX, scene.impulseY);
    gl.uniform1f(uniform.age, time - scene.impulseTime);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
  function tick(now) {
    frame = 0;
    const delta = previous ? Math.min((now - previous) / 1000, .05) : 0;
    previous = now;
    time += delta;
    if (now - lastDraw >= (touch.matches ? 30 : 14)) {
      const ease = 1 - Math.exp(-delta * 6);
      for (const scene of scenes) {
        if (!scene.visible || scene.lost) continue;
        scene.x += (scene.targetX - scene.x) * ease;
        scene.y += (scene.targetY - scene.y) * ease;
        scene.hover += (scene.targetHover - scene.hover) * ease;
        draw(scene);
      }
      lastDraw = now;
    }
    frame = requestAnimationFrame(tick);
  }
  function sync() {
    for (const scene of scenes) {
      scene.control.hidden = reduced.matches || scene.lost;
      scene.control.textContent = paused ? 'Play motion' : 'Pause motion';
      scene.control.setAttribute('aria-pressed', String(paused));
      scene.section.dataset.motion = reduced.matches ? 'reduced' : paused ? 'paused' : scene.visible && !document.hidden ? 'playing' : 'idle';
    }
    const run = !paused && !reduced.matches && !document.hidden && scenes.some(scene => scene.visible && !scene.lost);
    if (run && !frame) { previous = 0; frame = requestAnimationFrame(tick); }
    if (!run && frame) { cancelAnimationFrame(frame); frame = 0; previous = 0; }
  }
  const observer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      const scene = scenes.find(item => item.section === entry.target);
      if (scene) scene.visible = entry.isIntersecting;
    }
    sync();
  }, { threshold: 0 });
  document.addEventListener('visibilitychange', sync);
  window.addEventListener('pagehide', () => { cancelAnimationFrame(frame); frame = 0; });
  window.addEventListener('pageshow', sync);
  reduced.addEventListener('change', () => { if (!reduced.matches && !scenes.length) load(); sync(); });
  let loading = false;
  function load() {
    if (loading) return;
    loading = true;
    const artwork = new Image();
    artwork.onload = () => { sections.forEach(section => createScene(section, artwork)); sync(); };
    artwork.src = '/assets/landscape.webp';
  }
  if (!reduced.matches) load();
})();
