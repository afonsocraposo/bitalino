package com.afonsoraposo.bitalino;

import android.app.Activity;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Parcelable;
import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import info.plux.pluxapi.Communication;
import info.plux.pluxapi.Constants;
import info.plux.pluxapi.bitalino.BITalinoCommunicationFactory;
import info.plux.pluxapi.bitalino.BITalinoDescription;
import info.plux.pluxapi.bitalino.BITalinoErrorTypes;
import info.plux.pluxapi.bitalino.BITalinoException;
import info.plux.pluxapi.bitalino.BITalinoFrame;
import info.plux.pluxapi.bitalino.BITalinoState;
import info.plux.pluxapi.bitalino.bth.OnBITalinoDataAvailable;
import io.flutter.Log;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.Result;
import info.plux.pluxapi.bitalino.BITalinoCommunication;
import static android.content.ContentValues.TAG;


final class BITalino implements MethodChannel.MethodCallHandler {
    private final Activity activity;
    private final MethodChannel methodChannel;
    private final EventChannel dataStreamChannel;
    private BITalinoCommunication bitalinoCommunication;
    private Result descriptionResult;
    private Result stateResult;
    private Result connectResult;
    private Result disconnectResult;
    private Result startResult;
    private Result stopResult;
    private EventChannel.EventSink dataStreamSink;


    BITalino(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;

        methodChannel = new MethodChannel(messenger, "com.afonsoraposo.bitalino/bitalino");
        dataStreamChannel = new EventChannel(messenger, "com.afonsoraposo.bitalino/dataStream");
        methodChannel.setMethodCallHandler(this);
    }

    private final BroadcastReceiver updateReceiver = new BroadcastReceiver() {  @Override
        public void onReceive(Context context, Intent intent) {
            final String action = intent.getAction();
            if (Constants.ACTION_STATE_CHANGED.equals(action)) {
                String identifier = intent.getStringExtra(Constants.IDENTIFIER);
                Constants.States state = Constants.States.getStates(intent.getIntExtra(Constants.EXTRA_STATE_CHANGED,0));
                //Log.i(TAG, "Device " + identifier + ": " + state.name());
                switch (state.name()){
                    case "CONNECTED":
                        if(connectResult!=null){
                            connectResult.success(true);
                            connectResult = null;
                        }
                        if(stopResult!=null){
                            stopResult.success(true);
                            stopResult=null;
                        }
                        break;
                    case "DISCONNECTED":
                        if(disconnectResult!=null){
                            disconnectResult.success(true);
                            disconnectResult = null;
                        }else{
                            if(connectResult!=null){
                                connectResult.success(false);
                            }else{
                                methodChannel.invokeMethod("lostConnection", null);
                            }
                        }
                        break;
                    case "ACQUISITION_OK":
                        if(startResult!=null){
                            startResult.success(true);
                            startResult = null;
                        }
                        break;
                    default:
                        break;
                }
            } else if (Constants.ACTION_DATA_AVAILABLE.equals(action)) {
                BITalinoFrame frame = intent.getParcelableExtra(Constants.EXTRA_DATA);
                //Log.d(TAG, "BITalinoFrame: " + frame.toString());
            } else if (Constants.ACTION_COMMAND_REPLY.equals(action)) {
                String identifier = intent.getStringExtra(Constants.IDENTIFIER);
                Parcelable parcelable = intent.getParcelableExtra(Constants.EXTRA_COMMAND_REPLY);
                if(parcelable.getClass().equals(BITalinoState.class)){
                    //Log.d(TAG, "BITalinoState: " + parcelable.toString());
                    if(stateResult!=null){
                        BITalinoState state = ((BITalinoState) parcelable);
                        int[] analog = new int[6];
                        int[] digital = new int[4];
                        // for some reason the channels' values come inverted
                        for(int i = 0; i<analog.length; i++){
                            analog[i] = state.getAnalog(analog.length-1-i);
                        }
                        for(int i = 0; i<digital.length; i++){
                            digital[i] = state.getDigital(digital.length-1-i);
                        }
                        final Map<String, Object> dataBuffer = new HashMap<>();
                        dataBuffer.put("identifier", state.getIdentifier());
                        dataBuffer.put("battery", state.getBattery());
                        dataBuffer.put("batteryThreshold", state.getBatThreshold());
                        dataBuffer.put("analog", analog);
                        dataBuffer.put("digital", digital);
                        stateResult.success(dataBuffer);
                        stateResult = null;
                    }
                } else if(parcelable.getClass().equals(BITalinoDescription.class)){
                    //Log.d(TAG,  "BITalinoDescription: isBITalino2: " + ((BITalinoDescription)parcelable).isBITalino2() +  "; FwVersion: " + ((BITalinoDescription)parcelable).getFwVersion());
                    if(descriptionResult!=null){
                        BITalinoDescription description = (BITalinoDescription)parcelable;
                        final Map<String, Object> dataBuffer = new HashMap<>();
                        dataBuffer.put("isBITalino2", description.isBITalino2());
                        dataBuffer.put("fwVersion", ""+description.getFwVersion());
                        descriptionResult.success(dataBuffer);
                        descriptionResult = null;
                    }
                }
            } else if (Constants.ACTION_MESSAGE_SCAN.equals(action)){
                BluetoothDevice device = intent.getParcelableExtra(Constants.EXTRA_DEVICE_SCAN);
            }
        }
    };

    protected static IntentFilter updateIntentFilter() {
        final IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(Constants.ACTION_STATE_CHANGED);
        intentFilter.addAction(Constants.ACTION_DATA_AVAILABLE);
        intentFilter.addAction(Constants.ACTION_COMMAND_REPLY);
        intentFilter.addAction(Constants.ACTION_MESSAGE_SCAN);
        return intentFilter;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
        switch (call.method) {
            case "initialize":
                try {
                    if(call.argument("type")!=null) {
                        final int type = call.argument("type");
                        final Communication communication = Communication.getById(type);
                        if (type == 1) {
                            bitalinoCommunication = new BITalinoCommunicationFactory().getCommunication(
                                    communication, activity.getBaseContext(), new OnBITalinoDataAvailable() {
                                        @Override
                                        public void onBITalinoDataAvailable(BITalinoFrame bitalinoFrame) {
                                            try {
                                                sendToDataStreamChannel(bitalinoFrame);
                                            } catch (Exception e) {
                                                e.printStackTrace();
                                            }
                                        }
                                    });
                            startDataStream(dataStreamChannel);
                        } else if (type == 2) {
                            bitalinoCommunication = new BITalinoCommunicationFactory().getCommunication(
                                    communication, activity.getBaseContext());
                        }
                        activity.registerReceiver(updateReceiver, updateIntentFilter());
                        result.success(true);
                    }else{
                        throw new Exception("A valid bluetooth connection type must be provided.");
                    }
                } catch (Exception e) {
                    e.printStackTrace();
                    result.error("BITalinoCommunicationFactory", e.getMessage(), null);
                }
                break;
            case "connect":
                try {
                    connectResult = result;
                    if(!bitalinoCommunication.connect((String) call.argument("address"))){
                        throw new BITalinoException(BITalinoErrorTypes.BT_DEVICE_NOT_CONNECTED);
                    }
                } catch (BITalinoException e) {
                    connectResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "disconnect":
                try {
                    disconnectResult = result;
                    bitalinoCommunication.disconnect();
                } catch (BITalinoException e) {
                    disconnectResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication",e.getMessage(), null);
                }
                break;
            case "dispose":
                try {
                    bitalinoCommunication.closeReceivers();
                    bitalinoCommunication.disconnect();
                    cancelDataStreamSink();
                    result.success(true);
                } catch (Exception e) {
                    e.printStackTrace();
                    result.error("BITalinoCommunication",e.getMessage(), null);
                }
                break;
            case "description":
                try {
                    descriptionResult = result;
                    bitalinoCommunication.getVersion();
                } catch (BITalinoException e) {
                    descriptionResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication",e.getMessage(), null);
                }
                break;
            case "state":
                try {
                    stateResult = result;
                    if(!bitalinoCommunication.state()){
                        throw new BITalinoException(BITalinoErrorTypes.UNDEFINED);
                    }
                } catch (BITalinoException e) {
                    stateResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "batteryThreshold":
                try{
                    final int threshold = call.argument("threshold");
                    result.success(bitalinoCommunication.battery(threshold));
                } catch (BITalinoException e) {
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "start":
                try{
                    final ArrayList<Integer> channels = call.argument("analogChannels");
                    final int sampleRate = call.argument("sampleRate");
                    startResult = result;
                    if(!bitalinoCommunication.start(convertIntegers(channels), sampleRate)){
                        startResult=null;
                        result.success(false);
                    }
                } catch (BITalinoException e) {
                    startResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "stop":
                try{
                    stopResult = result;
                    if(bitalinoCommunication.stop()) { // for some reason, the code returns false if sent successfully
                        stopResult = null;
                        result.success(false);
                    }
                }catch(BITalinoException e) {
                    stopResult = null;
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "trigger":
                try{
                    final ArrayList<Integer> channels = call.argument("digitalChannels");
                    result.success(bitalinoCommunication.trigger(convertIntegers(channels)));
                } catch (BITalinoException e) {
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            case "pwm":
                try{
                    final int pwmOutput = call.argument("pwmOutput");
                    result.success(bitalinoCommunication.pwm(pwmOutput));
                } catch (BITalinoException e) {
                    e.printStackTrace();
                    result.error("BITalinoCommunication", e.getMessage(), null);
                }
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    void stopListening() {
        methodChannel.setMethodCallHandler(null);
    }

    void startDataStream(final EventChannel dataStreamChannel){
        dataStreamChannel.setStreamHandler(
        new EventChannel.StreamHandler() {
          @Override
          public void onListen(Object o, EventChannel.EventSink dataStreamSink) {
            setDataStreamSink(dataStreamSink);
          }

          @Override
          public void onCancel(Object o) {
              cancelDataStreamSink();
          }
        });
    }

    private void setDataStreamSink(EventChannel.EventSink dataStreamSink){
        this.dataStreamSink = dataStreamSink;
    }

    private void cancelDataStreamSink(){
        this.dataStreamSink = null;
    }

    void sendToDataStreamChannel(BITalinoFrame frame) throws Exception {
        if(dataStreamSink!=null) {
            final Map<String, Object> dataBuffer = new HashMap<>();
            dataBuffer.put("identifier", frame.getIdentifier());
            dataBuffer.put("sequence", frame.getSequence());
            dataBuffer.put("analog", frame.getAnalogArray());
            dataBuffer.put("digital", frame.getDigitalArray());
            activity.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    dataStreamSink.success(dataBuffer);
                }
            });
        }else{
            throw new Exception("No channel available.");
        }
    }

    public static int[] convertIntegers(List<Integer> integers)
    {
        int[] ret = new int[integers.size()];
        Iterator<Integer> iterator = integers.iterator();
        for (int i = 0; i < ret.length; i++)
        {
            ret[i] = iterator.next().intValue();
        }
        return ret;
    }

}
