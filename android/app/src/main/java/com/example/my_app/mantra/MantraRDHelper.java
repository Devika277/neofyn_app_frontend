package com.example.my_app.mantra;

import android.content.Context;
import android.content.pm.PackageManager;

public class MantraRDHelper {

    // Mantra has shipped its RD Service Android app under different package
    // names across MFS100 / MFS110 / L1 driver generations. Only the first
    // entry below is independently confirmed (Play Store listing lookup);
    // the rest are commonly-seen historical variants and MUST be confirmed
    // against what's actually installed on your field devices before you
    // trust this list — run `adb shell pm list packages | grep mantra` on
    // a real device to get the authoritative name(s) in your fleet.
    private static final String[] RD_PACKAGES = {
            "com.mantra.mfs110.rdservice",   // confirmed via Play Store, MFS110 L1
            "com.mantra.rdservice",          // TODO — VERIFY: older MFS100 generation
            "com.mantra.mfs100.rdservice",   // TODO — VERIFY: alternate MFS100 naming
    };

    private Context context;
    private String detectedPackage = null;

    public MantraRDHelper(Context context) {
        this.context = context;
    }

    public String detectRDService() {
        PackageManager pm = context.getPackageManager();
        for (String pkg : RD_PACKAGES) {
            try {
                pm.getPackageInfo(pkg, PackageManager.GET_ACTIVITIES);
                detectedPackage = pkg;
                return pkg;
            } catch (Exception e) {
                // not installed under this name, try next candidate
            }
        }
        detectedPackage = null;
        return null;
    }

    public String getDetectedPackage() {
        if (detectedPackage == null) detectRDService();
        return detectedPackage;
    }
}
