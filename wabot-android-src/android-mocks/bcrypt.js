// Android mock — bcrypt (redirige vers bcryptjs pur JS)
  try {
    module.exports = require('bcryptjs');
  } catch(e) {
    // Fallback minimal si bcryptjs pas installé
    module.exports = {
      hash: async (data, salt) => data + '_hashed',
      compare: async (data, hash) => hash.startsWith(data),
      hashSync: (data) => data + '_hashed',
      compareSync: (data, hash) => hash.startsWith(data),
      genSalt: async (rounds) => 'salt_' + rounds,
    };
  }
  