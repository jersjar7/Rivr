package com.byuhydroinformaticslab.rivr

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class MapboxTokenPlugin(private val context: Context) : MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getMapboxToken") {
      val applicationInfo = context.packageManager.getApplicationInfo(
        context.packageName, PackageManager.GET_META_DATA)
      val token = applicationInfo.metaData.getString("com.mapbox.token")
      result.success(token)
    } else {
      result.notImplemented()
    }
  }
}