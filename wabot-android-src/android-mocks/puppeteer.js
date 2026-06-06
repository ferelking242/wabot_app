// Android mock — puppeteer
  module.exports = {
    launch: () => Promise.reject(new Error('puppeteer not available on Android')),
    connect: () => Promise.reject(new Error('puppeteer not available on Android')),
    executablePath: () => '',
    defaultArgs: () => [],
  };
  