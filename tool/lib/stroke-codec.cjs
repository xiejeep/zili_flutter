/* Compact stroke path codec shared by the build script and the app runtime.
 * Coordinates are halved before delta encoding and restored on decode, so most
 * deltas fit in a single character and the payload stays small enough for the
 * mini program package limit. */
(function(root) {
  // Printable ASCII minus " and the JSON escapes.
  var CHARS = (function() {
    var out = '';
    for (var c = 33; c <= 126; c++) {
      if (c === 34 || c === 39 || c === 92) continue;
      out += String.fromCharCode(c);
    }
    return out;
  })();
  var BASE = CHARS.length, ESC = BASE - 1, SHORT = 44, SCALE = 2, INDEX = {};
  for (var i = 0; i < BASE; i++) INDEX[CHARS[i]] = i;

  function put(value) {
    if (value >= -SHORT && value <= SHORT) return CHARS[value + SHORT];
    var v = value + 4000;
    if (v < 0 || v >= BASE * BASE) throw new Error('stroke coordinate out of range');
    return CHARS[ESC] + CHARS[Math.floor(v / BASE)] + CHARS[v % BASE];
  }

  function read(str, pos) {
    var code = INDEX[str[pos]];
    if (code === undefined) throw new Error('bad stroke payload');
    if (code === ESC) {
      var v = INDEX[str[pos + 1]] * BASE + INDEX[str[pos + 2]];
      return [v - 4000, pos + 3];
    }
    return [code - SHORT, pos + 1];
  }

  function encodePath(source) {
    var tokens = source.match(/[MLQCZ]|-?\d+(?:\.\d+)?/g) || [], out = '', i = 0, x = 0, y = 0;
    while (i < tokens.length) {
      var op = tokens[i++];
      if (op === 'Z') { out += 'Z'; continue; }
      out += op;
      var count = op === 'Q' ? 2 : op === 'C' ? 3 : 1;
      for (var k = 0; k < count; k++) {
        var nx = Math.round(Number(tokens[i++]) / SCALE), ny = Math.round(Number(tokens[i++]) / SCALE);
        out += put(nx - x) + put(ny - y);
        x = nx; y = ny;
      }
    }
    return out;
  }

  function decodePath(text) {
    var strokes = '', points = [], i = 0, x = 0, y = 0;
    while (i < text.length) {
      var op = text[i++];
      if (op === 'Z') { strokes += 'Z'; continue; }
      var count = op === 'Q' ? 2 : op === 'C' ? 3 : 1, coords = [];
      for (var k = 0; k < count; k++) {
        var rx = read(text, i); x += rx[0]; i = rx[1];
        var ry = read(text, i); y += ry[0]; i = ry[1];
        coords.push(x * SCALE, y * SCALE);
      }
      strokes += op + coords.join(' ');
      points.push([coords[coords.length - 2], coords[coords.length - 1]]);
    }
    return { path: strokes, points: points };
  }

  function encodePoints(points) {
    var out = '', x = 0, y = 0;
    for (var i = 0; i < points.length; i++) {
      var nx = Math.round(points[i][0] / SCALE), ny = Math.round(points[i][1] / SCALE);
      out += put(nx - x) + put(ny - y);
      x = nx; y = ny;
    }
    return out;
  }

  function decodePoints(text) {
    var out = [], i = 0, x = 0, y = 0;
    while (i < text.length) {
      var rx = read(text, i); x += rx[0]; i = rx[1];
      var ry = read(text, i); y += ry[0]; i = ry[1];
      out.push([x * SCALE, y * SCALE]);
    }
    return out;
  }

  function encode(charData) {
    return charData.strokes.map(encodePath).join(' ') + '\n' +
      (charData.medians || []).map(encodePoints).join(' ');
  }

  function decode(payload) {
    var parts = payload.split('\n');
    var strokes = [], medians = [];
    (parts[0] ? parts[0].split(' ') : []).forEach(function(p) {
      var d = decodePath(p);
      strokes.push(d.path);
      medians.push(d.points);
    });
    if (parts[1] && parts[1].length) {
      // Shipped medians are denser than the skeleton recovered from paths and
      // drive both the animation and the tracing check.
      medians = parts[1].split(' ').map(decodePoints);
    }
    return { strokes: strokes, medians: medians };
  }

  var api = { encode, decode, encodePath, decodePath, encodePoints, decodePoints };
  if (typeof module !== 'undefined') module.exports = api; else root.ZiliStrokeCodec = api;
})(typeof window !== 'undefined' ? window : this);
