package com.example.my_app.morpho;

import android.content.Context;
import android.content.pm.PackageManager;

public class MorphoRDHelper {

    private static final String[] RD_PACKAGES = {
            "com.scl.morpho.rdservice",
            "com.morpho.mso1300.rdservice",
            "com.morpho.rdservice.l1",
            "in.morpho.mso1300.rdservice"
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
            } catch (Exception e) {}
        }
        return null;
    }

    public String getDetectedPackage() {
        if (detectedPackage == null) detectRDService();
        return detectedPackage;
    }
}