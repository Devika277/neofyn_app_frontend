package com.example.my_app.morpho;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import androidx.annotation.NonNull;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

public class MorphoPlugin implements FlutterPlugin, MethodCallHandler,
        ActivityAware, PluginRegistry.ActivityResultListener {

    private static final String CHANNEL = "com.example.my_app/morpho";

    // Per IDEMIA L1 RD Service integration doc (section 6.1 / 6.3)
    private static final String ACTION_DEVICE_INFO = "in.gov.uidai.rdservice.fp.INFO";
    private static final String ACTION_CAPTURE = "in.gov.uidai.rdservice.fp.CAPTURE";

    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private MorphoRDHelper rdHelper;
    private Result pendingResult;

    private static final int DEVICE_INFO_REQUEST = 1000;
    private static final int CAPTURE_REQUEST = 1001;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        rdHelper = new MorphoRDHelper(context);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initialize":
                initMorpho(result);
                break;
            case "checkDevice":
                checkDevice(result);
                break;
            case "captureFingerprint":
                captureFingerprint(call, result);
                break;
            case "openRDService":
                openRDService(result);
                break;
            default:
                result.notImplemented();
        }
    }

    private void initMorpho(Result result) {
        String pkg = rdHelper.detectRDService();
        Map<String, Object> map = new HashMap<>();
        map.put("success", pkg != null);
        map.put("package", pkg);
        result.success(map);
    }

    /**
     * "installed" just checks the APK exists. This alone previously reported
     * false because the package name list was wrong. Real readiness is only
     * confirmed by actually firing the DEVICE_INFO intent and getting RESULT_OK.
     */
    private void checkDevice(Result result) {
        String pkg = rdHelper.getDetectedPackage();
        Map<String, Object> map = new HashMap<>();
        map.put("rdServiceInstalled", pkg != null);
        map.put("package", pkg);

        if (pkg == null || activity == null) {
            result.success(map);
            return;
        }

        // Fire DEVICE_INFO to confirm the service actually responds.
        pendingResult = result;
        Intent intent = new Intent(ACTION_DEVICE_INFO);
        intent.setPackage(pkg);
        try {
            activity.startActivityForResult(intent, DEVICE_INFO_REQUEST);
        } catch (Exception e) {
            pendingResult = null;
            result.success(map); // fall back to install-only info
        }
    }

    private void captureFingerprint(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null);
            return;
        }

        String rdPackage = rdHelper.getDetectedPackage();
        if (rdPackage == null) {
            result.error("NO_RD", "IDEMIA L1 RD Service (com.idemia.l1rdservice) not found. "
                    + "Install it from the Play Store or sideload the APK.", null);
            return;
        }

        pendingResult = result;

        // Prefer the XML built by Dart (biometric_service.dart's _buildPidOptionsXml),
        // which correctly includes the real wadh/clientKey for this request.
        // Only fall back to a default here if Dart didn't pass one (shouldn't normally happen).
        String pidXml = call.argument("pidOptionsXml");
        if (pidXml == null || pidXml.isEmpty()) {
            pidXml = "<PidOptions ver=\"2.0\">" +
                    "<Opts fCount=\"1\" fType=\"2\" iCount=\"0\" pCount=\"0\" format=\"0\" " +
                    "pidVer=\"2.0\" timeout=\"20000\" posh=\"UNKNOWN\" env=\"P\" wadh=\"\"/>" +
                    "<Demo></Demo>" +
                    "<CustOpts></CustOpts>" +
                    "</PidOptions>";
        }

        Intent intent = new Intent(ACTION_CAPTURE);
        intent.setPackage(rdPackage);
        intent.putExtra("PID_OPTIONS", pidXml);
        activity.startActivityForResult(intent, CAPTURE_REQUEST);
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == DEVICE_INFO_REQUEST) {
            if (pendingResult == null) return true;
            Map<String, Object> map = new HashMap<>();
            map.put("rdServiceInstalled", true);
            map.put("package", rdHelper.getDetectedPackage());
            if (resultCode == Activity.RESULT_OK && data != null) {
                Bundle b = data.getExtras();
                if (b != null) {
                    map.put("deviceInfo", b.getString("DEVICE_INFO", ""));
                    map.put("rdServiceInfo", b.getString("RD_SERVICE_INFO", ""));
                    map.put("ready", true);
                } else {
                    map.put("ready", false);
                }
            } else {
                map.put("ready", false);
            }
            pendingResult.success(map);
            pendingResult = null;
            return true;
        }

        if (requestCode == CAPTURE_REQUEST) {
            if (pendingResult == null) return true;
            Map<String, Object> map = new HashMap<>();
            if (resultCode == Activity.RESULT_OK && data != null) {
                Bundle b = data.getExtras();
                String pid = b != null ? b.getString("PID_DATA") : null;
                String dnc = b != null ? b.getString("DNC", "") : "";
                String dnr = b != null ? b.getString("DNR", "") : "";

                if (pid != null && !pid.isEmpty()) {
                    map.put("success", true);
                    map.put("pidData", pid);
                } else if (dnc != null && !dnc.isEmpty()) {
                    map.put("success", false);
                    map.put("error", "Device not connected");
                } else if (dnr != null && !dnr.isEmpty()) {
                    map.put("success", false);
                    map.put("error", "Device not registered");
                } else {
                    map.put("success", false);
                    map.put("error", "Capture returned no data");
                }
            } else {
                map.put("success", false);
                map.put("error", "Capture cancelled or failed (resultCode=" + resultCode + ")");
            }
            pendingResult.success(map);
            pendingResult = null;
            return true;
        }

        return false;
    }

    private void openRDService(Result result) {
        String pkg = rdHelper.getDetectedPackage();
        if (pkg == null) {
            result.error("NO_RD", "RD Service not found", null);
            return;
        }
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(pkg);
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            result.success(true);
        } else {
            result.error("ERROR", "Cannot open RD Service", null);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }
}