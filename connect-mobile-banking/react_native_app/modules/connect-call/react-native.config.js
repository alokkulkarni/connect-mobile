module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: 'import com.connectbanking.call.ConnectCallPackage;',
        packageInstance: 'new ConnectCallPackage()',
      },
      ios: {},
    },
  },
};
