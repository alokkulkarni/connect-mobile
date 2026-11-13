package com.connectbanking.call

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class ConnectCallPackage : ReactPackage {
    @Suppress("DEPRECATION")
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> = listOf(ConnectCallModule(reactContext))

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> = emptyList()
}
