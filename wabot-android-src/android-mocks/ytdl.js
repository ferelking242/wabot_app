// Android mock — ytdl-core
  // ytdl est pure JS mais certaines commandes l'utilisent avec ffmpeg
  // On le laisse fonctionner pour les downloads audio/vidéo via API
  module.exports = {
    getInfo: () => Promise.reject(new Error('ytdl not available on Android — use API alternatives')),
    getBasicInfo: () => Promise.reject(new Error('ytdl not available on Android')),
    validateURL: () => false,
    chooseFormat: () => null,
  };
  