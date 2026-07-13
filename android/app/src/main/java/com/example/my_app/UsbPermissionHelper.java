package com.example.my_app;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.util.Log;

import androidx.core.content.ContextCompat;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

import java.util.HashMap;
import java.util.Map;

public class UsbPermissionHelper implements MethodCallHandler {
    private static final String TAG = "UsbPermissionHelper";
    private static final String ACTION_USB_PERMISSION = "com.example.my_app.USB_PERMISSION";
    
    private final Context context;
    private final UsbManager usbManager;
    private MethodChannel channel;
    private Result pendingResult;
    
    private final BroadcastReceiver usbReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();
            if (ACTION_USB_PERMISSION.equals(action)) {
                synchronized (this) {
                    UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        if (device != null) {
                            Log.d(TAG, "USB Permission granted for device: " + device.getDeviceName());
                            if (pendingResult != null) {
                                Map<String, Object> result = new HashMap<>();
                                result.put("granted", true);
                                result.put("deviceName", device.getDeviceName());
                                result.put("vendorId", device.getVendorId());
                                result.put("productId", device.getProductId());
                                pendingResult.success(result);
                                pendingResult = null;
                            }
                        }
                    } else {
                        Log.d(TAG, "USB Permission denied");
                        if (pendingResult != null) {
                            pendingResult.error("PERMISSION_DENIED", "USB permission denied", null);
                            pendingResult = null;
                        }
                    }
                }
            } else if (UsbManager.ACTION_USB_DEVICE_ATTACHED.equals(action)) {
                UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if (device != null) {
                    Log.d(TAG, "USB Device Attached: " + device.getDeviceName());
                    if (channel != null) {
                        Map<String, Object> data = new HashMap<>();
                        data.put("event", "device_attached");
                        data.put("deviceName", device.getDeviceName());
                        data.put("vendorId", device.getVendorId());
                        data.put("productId", device.getProductId());
                        channel.invokeMethod("onUsbEvent", data);
                    }
                }
            } else if (UsbManager.ACTION_USB_DEVICE_DETACHED.equals(action)) {
                UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                if (device != null) {
                    Log.d(TAG, "USB Device Detached: " + device.getDeviceName());
                    if (channel != null) {
                        Map<String, Object> data = new HashMap<>();
                        data.put("event", "device_detached");
                        data.put("deviceName", device.getDeviceName());
                        channel.invokeMethod("onUsbEvent", data);
                    }
                }
            }
        }
    };

    public UsbPermissionHelper(Context context) {
        this.context = context;
        this.usbManager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
    }

    public void setChannel(MethodChannel channel) {
        this.channel = channel;
    }

    public void registerReceiver() {
        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_USB_PERMISSION);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        ContextCompat.registerReceiver(context, usbReceiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED);
    }

    public void unregisterReceiver() {
        try {
            context.unregisterReceiver(usbReceiver);
        } catch (Exception e) {
            Log.e(TAG, "Error unregistering receiver: " + e.getMessage());
        }
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "requestUsbPermission":
                Integer vendorId = call.argument("vendorId");
                Integer productId = call.argument("productId");
                if (vendorId != null && productId != null) {
                    requestPermission(vendorId, productId, result);
                } else {
                    result.error("INVALID_ARGS", "Vendor ID and Product ID required", null);
                }
                break;
                
            case "getConnectedDevices":
                getConnectedDevices(result);
                break;
                
            case "checkUsbPermission":
                Integer vId = call.argument("vendorId");
                Integer pId = call.argument("productId");
                if (vId != null && pId != null) {
                    checkPermission(vId, pId, result);
                } else {
                    result.error("INVALID_ARGS", "Vendor ID and Product ID required", null);
                }
                break;
                
            default:
                result.notImplemented();
                break;
        }
    }

    private void requestPermission(int vendorId, int productId, Result result) {
        pendingResult = result;
        UsbDevice device = findDevice(vendorId, productId);
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "USB device not found", null);
            pendingResult = null;
            return;
        }

        if (usbManager.hasPermission(device)) {
            Map<String, Object> response = new HashMap<>();
            response.put("granted", true);
            response.put("deviceName", device.getDeviceName());
            response.put("vendorId", device.getVendorId());
            response.put("productId", device.getProductId());
            result.success(response);
            pendingResult = null;
            return;
        }

        PendingIntent permissionIntent = PendingIntent.getBroadcast(
            context, 
            0, 
            new Intent(ACTION_USB_PERMISSION),
            PendingIntent.FLAG_IMMUTABLE
        );
        usbManager.requestPermission(device, permissionIntent);
    }

    private UsbDevice findDevice(int vendorId, int productId) {
        for (UsbDevice device : usbManager.getDeviceList().values()) {
            if (device.getVendorId() == vendorId && device.getProductId() == productId) {
                return device;
            }
        }
        return null;
    }

    private void checkPermission(int vendorId, int productId, Result result) {
        UsbDevice device = findDevice(vendorId, productId);
        if (device == null) {
            result.success(false);
            return;
        }
        result.success(usbManager.hasPermission(device));
    }

    private void getConnectedDevices(Result result) {
        Map<String, Object> devices = new HashMap<>();
        for (UsbDevice device : usbManager.getDeviceList().values()) {
            Map<String, Object> deviceInfo = new HashMap<>();
            deviceInfo.put("deviceName", device.getDeviceName());
            deviceInfo.put("vendorId", device.getVendorId());
            deviceInfo.put("productId", device.getProductId());
            deviceInfo.put("hasPermission", usbManager.hasPermission(device));
            devices.put(device.getDeviceName(), deviceInfo);
        }
        result.success(devices);
    }
}