// Android mock — sharp
  function sharp() {
    const self = {
      resize: () => self, toBuffer: () => Promise.reject(new Error('sharp not available on Android')),
      toFile: () => Promise.reject(new Error('sharp not available on Android')),
      jpeg: () => self, png: () => self, webp: () => self,
      composite: () => self, modulate: () => self, blur: () => self,
      sharpen: () => self, greyscale: () => self, grayscale: () => self,
      rotate: () => self, flip: () => self, flop: () => self,
      normalize: () => self, normalise: () => self,
      metadata: () => Promise.reject(new Error('sharp not available on Android')),
      stats: () => Promise.reject(new Error('sharp not available on Android')),
      clone: () => self,
    };
    return self;
  }
  sharp.cache = () => {};
  sharp.concurrency = () => 0;
  sharp.counters = () => ({});
  sharp.simd = () => false;
  module.exports = sharp;
  