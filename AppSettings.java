package com.example.graphhopperapp;


import android.content.Context;
import android.content.SharedPreferences;
import android.text.TextUtils;


import androidx.preference.PreferenceManager;


/**
* Type-safe accessor for the user-configurable settings that are stored in the
* default {@link SharedPreferences} by the preference screen.
*/
public class AppSettings {


   private final Context appContext;
   private final SharedPreferences prefs;


   public AppSettings(Context context) {
       this.appContext = context.getApplicationContext();
       this.prefs = PreferenceManager.getDefaultSharedPreferences(appContext);
   }


   /** GraphHopper Directions API key. Default value if not set by user. */
   public String getApiKey() {
       String def = appContext.getString(R.string.pref_default_api_key);
       String value = prefs.getString(appContext.getString(R.string.pref_key_api_key), def);
       return TextUtils.isEmpty(value) ? def : value.trim();
   }


   public boolean hasApiKey() {
       return !TextUtils.isEmpty(getApiKey());
   }


   /** API base URL, defaulting to the hosted GraphHopper endpoint. */
   public String getBaseUrl() {
       String def = appContext.getString(R.string.pref_default_base_url);
       String value = prefs.getString(appContext.getString(R.string.pref_key_base_url), def);
       if (TextUtils.isEmpty(value)) {
           value = def;
       }
       // Normalise: strip any trailing slash so we can append paths cleanly.
       while (value.endsWith("/")) {
           value = value.substring(0, value.length() - 1);
       }
       return value;
   }


   /** Vehicle/routing profile, e.g. car, bike, foot. */
   public String getProfile() {
       return prefs.getString(appContext.getString(R.string.pref_key_profile), "car");
   }


   /** Locale for instructions/geocoding, e.g. "en". */
   public String getLocale() {
       String def = appContext.getString(R.string.pref_default_locale);
       String value = prefs.getString(appContext.getString(R.string.pref_key_locale), def);
       return TextUtils.isEmpty(value) ? def : value;
   }
}
