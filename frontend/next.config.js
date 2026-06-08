/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  webpack: (config) => {
    config.resolve.alias = {
      ...config.resolve.alias,
      '@': require('path').resolve(__dirname),
      '@react-native-async-storage/async-storage': require.resolve('./empty-module.js'),
    };
    return config;
  },
};

module.exports = nextConfig;