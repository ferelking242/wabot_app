// Android mock — fluent-ffmpeg
  // Retourne un objet chainable qui ne fait rien
  function ffmpegMock(input) {
    const chain = new Proxy({}, {
      get(_, prop) {
        return (...args) => {
          // "run" et "save" déclenchent un callback d'erreur pour info
          if (prop === 'run' || prop === 'save') {
            const cb = args.find(a => typeof a === 'function');
            if (cb) setTimeout(() => cb(new Error('ffmpeg not available on Android')), 0);
          }
          return chain;
        };
      }
    });
    return chain;
  }
  ffmpegMock.ffprobe = (p, opts, cb) => {
    const fn = typeof opts === 'function' ? opts : cb;
    if (fn) fn(new Error('ffmpeg not available on Android'));
  };
  ffmpegMock.setFfmpegPath = () => {};
  ffmpegMock.setFfprobePath = () => {};
  module.exports = ffmpegMock;
  