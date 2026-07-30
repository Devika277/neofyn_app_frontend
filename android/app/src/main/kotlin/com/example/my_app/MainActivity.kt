package com.example.my_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.vimopay.matm.presentation.MatmStatusActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import com.example.my_app.morpho.MorphoPlugin
import com.example.my_app.mantra.MantraPlugin

class MainActivity : FlutterActivity() {

    private val CHANNEL_MATM = "com.example.my_app/matm"
    private val CHANNEL_USB = "usb_permission"
    private var pendingResult: MethodChannel.Result? = null
    private val REQUEST_CODE_MATM = 1001
    private val REQUEST_CODE_PERMISSIONS = 1002  // ADD THIS
    
    private var usbHelper: UsbPermissionHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── REQUEST PERMISSIONS ──────────────────────────────────────
        requestPermissions()  // ADD THIS

        // ─── EXISTING MATM CHANNEL ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_MATM)
            .setMethodCallHandler { call, result ->
                try {
                    val merchantId = call.argument<String>("merchantId") ?: ""

                    if (merchantId.isEmpty()) {
                        result.error("MISSING_MERCHANT_ID", "merchantId is required", null)
                        return@setMethodCallHandler
                    }

                    when (call.method) {
                        "startBalanceEnquiry" -> {
                            pendingResult = result
                            launchMatm(
                                txnCode = "BE",
                                remarks = "Balance Enquiry",
                                amount = "0",
                                merchantId = merchantId
                            )
                        }
                        "startCashWithdrawal" -> {
                            val amount = call.argument<String>("amount") ?: "0"
                            // ADD: Validate amount
                            if (amount.toDoubleOrNull() == null || amount.toDouble() <= 0) {
                                result.error("INVALID_AMOUNT", "Amount must be greater than 0", null)
                                return@setMethodCallHandler
                            }
                            pendingResult = result
                            launchMatm(
                                txnCode = "CW",
                                remarks = "Cash Withdrawal",
                                amount = amount,
                                merchantId = merchantId
                            )
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    Log.e("MATM_ERROR", "Error in method call", e)
                    result.error("EXCEPTION", e.message, null)
                }
            }

        // ─── EXISTING USB PERMISSION CHANNEL ──────────────────────────
        usbHelper = UsbPermissionHelper(this)
        val usbChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_USB)
        usbChannel.setMethodCallHandler(usbHelper)
        usbHelper?.setChannel(usbChannel)
        usbHelper?.registerReceiver()

        // ─── EXISTING MORPHO PLUGIN ────────────────────────────────────
        flutterEngine.plugins.add(MorphoPlugin())
   
           // ─── MANTRA PLUGIN ──────────────────────────────────────────────
        flutterEngine.plugins.add(MantraPlugin())
    }


    // ─── ADD: Permission Request Method ──────────────────────────────
    private fun requestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val permissions = mutableListOf<String>()
            
            // Required permissions from SDK spec (Page 51)
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) 
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
            }
            
            if (permissions.isNotEmpty()) {
                ActivityCompat.requestPermissions(this, permissions.toTypedArray(), REQUEST_CODE_PERMISSIONS)
            }
        }
    }

    // ─── ADD: Permission Result Handler ──────────────────────────────
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            grantResults.forEachIndexed { index, result ->
                if (result != PackageManager.PERMISSION_GRANTED) {
                    Log.w("MATM_PERMISSION", "Permission ${permissions[index]} was denied")
                }
            }
        }
    }

    // ─── UPDATED MATM METHODS ──────────────────────────────────────────
    private fun launchMatm(
        txnCode: String,
        remarks: String,
        amount: String,
        merchantId: String
    ) {
        try {
            // ADD: Get credentials from BuildConfig
            val secretKey = BuildConfig.MATM_SECRET_KEY
            val saltKey = BuildConfig.MATM_SALT_KEY
            val encryptKey = BuildConfig.MATM_ENCRYPT_KEY
            val userId = BuildConfig.MATM_USER_ID

            Log.d("MATM_DEBUG", "=== mATM Transaction ===")
            Log.d("MATM_DEBUG", "txnCode=$txnCode | merchantId=$merchantId | amount=$amount")
            
            // ADD: Validate credentials
            if (secretKey.isEmpty() || saltKey.isEmpty() || encryptKey.isEmpty() || userId.isEmpty()) {
                val error = "mATM credentials not configured. Check local.properties"
                Log.e("MATM_DEBUG", error)
                pendingResult?.error("MISSING_CREDENTIALS", error, null)
                pendingResult = null
                return
            }

            // ADD: Generate shorter merchantRefId (SDK expects specific format)
            val merchantRefId = UUID.randomUUID().toString().replace("-", "").take(16)
            Log.d("MATM_DEBUG", "merchantRefId: $merchantRefId")

            val intent = Intent(this, MatmStatusActivity::class.java).apply {
                // ADD: Required credentials
                putExtra("secretKey", secretKey)
                putExtra("saltKey", saltKey)
                putExtra("encryptDecryptKey", encryptKey)
                putExtra("userId", userId)
                
                // Keep existing parameters
                putExtra("merchantId", merchantId)
                putExtra("pipe", "1")  // UAT pipe value
                putExtra("txnCode", txnCode)
                putExtra("merchantRefId", merchantRefId)  // UPDATED: Use shorter format
                putExtra("remarks", remarks)
                putExtra("amount", amount)
                putExtra("lat", "28.6139")
                putExtra("long", "77.2090")
            }
            startActivityForResult(intent, REQUEST_CODE_MATM)
            
        } catch (e: Exception) {
            Log.e("MATM_ERROR", "Failed to launch mATM", e)
            pendingResult?.error("LAUNCH_ERROR", e.message, null)
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_MATM) {
            Log.d("MATM_DEBUG", "resultCode=$resultCode")
            data?.extras?.keySet()?.forEach { key ->
                Log.d("MATM_DEBUG", "  $key = ${data.extras?.get(key)}")
            }

            when (resultCode) {
                RESULT_OK -> {
                    val response = data?.getStringExtra("response") 
                        ?: data?.getStringExtra("message")
                        ?: "Success"
                    Log.d("MATM_DEBUG", "SUCCESS: $response")
                    pendingResult?.success(response)
                }
                RESULT_CANCELED -> {
                    // UPDATED: Better error extraction
                    val error = data?.getStringExtra("error")
                        ?: data?.getStringExtra("message")
                        ?: data?.getStringExtra("msg")
                        ?: data?.getStringExtra("status")
                        ?: data?.getStringExtra("statusCode")
                        ?: "Transaction cancelled"
                    Log.d("MATM_DEBUG", "CANCELLED/ERROR: $error")
                    pendingResult?.error("MATM_ERROR", error, null)
                }
            }
            pendingResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up USB receiver
        usbHelper?.unregisterReceiver()
        // Clean up pending result
        if (pendingResult != null) {
            try {
                pendingResult?.error("ACTIVITY_DESTROYED", "Activity destroyed", null)
            } catch (e: Exception) {
                // Ignore
            }
            pendingResult = null
        }
    }
}