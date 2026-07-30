package com.example.my_app.morpho;

import android.content.Context;
import android.content.pm.PackageManager;

public class MorphoRDHelper {

    // Per IDEMIA "RD Services Solution for Android - L1" integration doc, section 14:
    // Package Name: "com.idemia.l1rdservice"
    private static final String[] RD_PACKAGES = {
            "com.idemia.l1rdservice"
    };

    private Context context;
    private String detectedPackage = null;

    public MorphoRDHelper(Context context) {
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
                // not installed, try next
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