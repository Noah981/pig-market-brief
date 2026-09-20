package com.example.dondonhae

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

class DataRefreshWorker(context:Context,params:WorkerParameters):Worker(context,params){
 override fun doWork():Result=try{PriceWidgetStore.fetch(applicationContext);DiseaseAlertStore.fetch(applicationContext);Result.success()}catch(_:Exception){Result.retry()}
}
