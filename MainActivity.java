package com.falldetection.app;

import android.Manifest;
import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.media.MediaPlayer;
import android.os.Bundle;
import android.os.Environment;
import android.view.View;
import android.widget.Button;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import java.io.*;
import java.net.URL;
import java.net.URLConnection;
import java.nio.charset.Charset;
import java.util.concurrent.TimeUnit;

public class MainActivity extends AppCompatActivity implements SensorEventListener {
    
    private Button startButton, stopButton;
    private SensorManager sensorManager;
    private Sensor accelerometer, gyroscope, orientation;
    private static float[] accelerometer_data = new float[3];
    private static float[] gyroscope_data = new float[3]; 
    private static float[] orientation_data = new float[3];
    
    private File file;
    private int off = 0;
    private long unixTimename;
    private Timer timer;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        startButton = findViewById(R.id.startButton);
        stopButton = findViewById(R.id.stopButton);
        
        sensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE);
        orientation = sensorManager.getDefaultSensor(Sensor.TYPE_ORIENTATION);
        
        ActivityCompat.requestPermissions(this, new String[]{
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
            Manifest.permission.INTERNET
        }, 100);
    }
    
    public void start(View v) throws InterruptedException {
        off = 0;
        unixTimename = System.currentTimeMillis() / 1000L;
        
        // Create CSV file
        File sdCard = Environment.getExternalStorageDirectory();
        File dir = new File(sdCard.getAbsolutePath() + "/sean");
        dir.mkdirs();
        file = new File(dir, "output"+unixTimename+".csv");
        
        String entry = "timestamp,rel_time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,azimuth,pitch,roll\n";
        try {
            FileOutputStream f = new FileOutputStream(file, true);
            f.write(entry.getBytes());
            f.flush();
            f.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
        
        final MediaPlayer mp = MediaPlayer.create(this, R.raw.startton);
        mp.start();
        TimeUnit.SECONDS.sleep(5);
        mp.start();
        
        sensorManager.registerListener(MainActivity.this, accelerometer, SensorManager.SENSOR_DELAY_FASTEST);
        sensorManager.registerListener(MainActivity.this, orientation, SensorManager.SENSOR_DELAY_FASTEST);
        sensorManager.registerListener(MainActivity.this, gyroscope, SensorManager.SENSOR_DELAY_FASTEST);
        
        timer = new Timer(this);
        timer.start();
    }
    
    public void stop(View v) {
        off = 1;
        sensorManager.unregisterListener(MainActivity.this, accelerometer);
        sensorManager.unregisterListener(MainActivity.this, orientation);
        sensorManager.unregisterListener(MainActivity.this, gyroscope);
        
        // Upload to FTP
        uploadToFTP();
    }
    
    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER)
            accelerometer_data = event.values;
        if (event.sensor.getType() == Sensor.TYPE_ORIENTATION)
            orientation_data = event.values;
        if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE)
            gyroscope_data = event.values;
    }
    
    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    
    private void uploadToFTP() {
        new Thread(() -> {
            StringBuilder sb = new StringBuilder();
            
            String ftpUrl = "ftp://%s:%s@%s/%s";
            String host = "192.168.1.100"; // Change to your PC IP
            String user = "USERNAME";
            String pass = "PASSWORD";
            String uploadPath = "test.csv";
            
            ftpUrl = String.format(ftpUrl, user, pass, host, uploadPath);
            
            try {
                FileReader fr = new FileReader("/storage/emulated/0/sean/output"+unixTimename+".csv");
                BufferedReader br = new BufferedReader(fr);
                String zeile = "";
                
                do {
                    zeile = br.readLine();
                    if (zeile == null) break;
                    sb.append(zeile + "\n");
                } while (zeile != null);
                
                br.close();
                
                URL url = new URL(ftpUrl);
                URLConnection conn = url.openConnection();
                conn.setDoOutput(true);
                OutputStream out = new BufferedOutputStream(conn.getOutputStream());
                BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(out, Charset.forName("UTF-8")));
                
                writer.write(String.valueOf(sb));
                writer.flush();
                writer.close();
                out.close();
                
                // Clear file
                FileOutputStream f2 = new FileOutputStream("/storage/emulated/0/sean/output" + unixTimename + ".csv", false);
                f2.write(("timestamp,rel_time,acc_x,acc_y,acc_z,gyro_x,gyro_y,gyro_z,azimuth,pitch,roll\n").getBytes());
                f2.flush();
                f2.close();
                
            } catch (Exception e) {
                e.printStackTrace();
            }
        }).start();
    }
    
    public class Timer extends Thread {
        private MainActivity activity;
        private float timer_1 = 0;
        private float timer_2 = 0;
        
        public Timer(MainActivity activity) {
            this.activity = activity;
        }
        
        @Override
        public void run() {
            while (off == 0) {
                try {
                    sleep(5);
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
                timer_1 = (float) (timer_1 + 0.0005);
                
                float[] gyroscope_data = MainActivity.gyroscope_data;
                float[] accelerometer_data = MainActivity.accelerometer_data;
                float[] orientation_data = MainActivity.orientation_data;
                
                if (accelerometer_data != null && orientation_data != null && gyroscope_data != null) {
                    final long unixTime = System.currentTimeMillis() / 1000L;
                    
                    String entry = unixTime + "," + timer_2 + "," + accelerometer_data[0] + "," + 
                                  accelerometer_data[1] + "," + accelerometer_data[2] + "," + 
                                  gyroscope_data[0] + "," + gyroscope_data[1] + "," + gyroscope_data[2] + "," + 
                                  orientation_data[0] + "," + orientation_data[1] + "," + orientation_data[2] + "\n";
                    
                    try {
                        FileOutputStream f = new FileOutputStream(file, true);
                        f.write(entry.getBytes());
                        f.flush();
                        f.close();
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }
        }
    }
}
