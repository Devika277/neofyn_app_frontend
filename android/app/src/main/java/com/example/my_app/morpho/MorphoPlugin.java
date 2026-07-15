package com.example.my_app.morpho;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
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
    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private MorphoRDHelper rdHelper;
    private Result pendingResult;
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

    private void checkDevice(Result result) {
        Map<String, Object> map = new HashMap<>();
        map.put("rdServiceInstalled", rdHelper.detectRDService() != null);
        map.put("package", rdHelper.getDetectedPackage());
        result.success(map);
    }

    private void captureFingerprint(MethodCall call, Result result) {
        if (activity == null) {
            result.error("NO_ACTIVITY", "Activity not available", null);
            return;
        }

        String rdPackage = rdHelper.getDetectedPackage();
        if (rdPackage == null) {
            result.error("NO_RD", "RD Service not found", null);
            return;
        }

        pendingResult = result;

        String pidXml = "<?xml version=\"1.0\"?>\n" +
                "<PidOptions ver=\"1.0\">\n" +
                "  <Opts fCount=\"1\" fType=\"2\" iCount=\"0\" pCount=\"0\" format=\"0\"\n" +
                "        pidVer=\"2.0\" timeout=\"30000\" posh=\"UNKNOWN\" env=\"P\" wadh=\"\"/>\n" +
                "</PidOptions>";

        Intent intent = new Intent();
        intent.setAction("com.morpho.rdservice.CAPTURE");
        intent.setPackage(rdPackage);
        intent.putExtra("PID_OPTIONS", pidXml);
        activity.startActivityForResult(intent, CAPTURE_REQUEST);
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == CAPTURE_REQUEST && pendingResult != null) {
            Map<String, Object> map = new HashMap<>();
            if (resultCode == Activity.RESULT_OK && data != null) {
                String pid = data.getStringExtra("PID_DATA");
                if (pid == null) pid = data.getStringExtra("response");
                map.put("success", pid != null);
                map.put("pidData", pid != null ? pid : "");
            } else {
                map.put("success", false);
                map.put("error", "Capture cancelled");
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