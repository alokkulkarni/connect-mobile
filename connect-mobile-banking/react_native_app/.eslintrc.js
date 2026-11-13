module.exports = {
  root: true,
  extends: '@react-native',
  rules: {
    // Styles are built from the theme's tokens at render time (light and dark), so they are inline by design.
    'react-native/no-inline-styles': 'off',
  },
};
