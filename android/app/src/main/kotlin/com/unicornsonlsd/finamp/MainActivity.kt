package com.unicornsonlsd.finamp

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import androidx.annotation.NonNull
import com.samsung.wearable_rotary.WearableRotaryPlugin
import android.view.MotionEvent

class MainActivity: FlutterActivity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    // remove background to support round screens on wear os
    intent.putExtra("background_mode", "transparent")
    super.onCreate(savedInstanceState)
  }

  // handle rotational input device using wearable_rotary
  override fun onGenericMotionEvent(event: MotionEvent?): Boolean {
    return when {
      WearableRotaryPlugin.onGenericMotionEvent(event) -> true
      else -> super.onGenericMotionEvent(event)
    }
  }
  
}
