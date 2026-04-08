package com.example.rfplayer

import android.annotation.SuppressLint
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import java.io.File
import java.io.FileOutputStream

object RealPathUtil {
    private const val TAG = "RealPathUtil"

    @SuppressLint("NewApi")
    fun getRealPath(context: Context, uri: Uri): String? {
        Log.d(TAG, "getRealPath: uri=$uri")
        
        // DocumentProvider
        if (DocumentsContract.isDocumentUri(context, uri)) {
            Log.d(TAG, "It's a DocumentProvider URI")
            
            // ExternalStorageProvider
            if (isExternalStorageDocument(uri)) {
                val docId = DocumentsContract.getDocumentId(uri)
                val split = docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                val type = split[0]
                
                if ("primary".equals(type, ignoreCase = true)) {
                    val path = Environment.getExternalStorageDirectory().toString() + "/" + split[1]
                    Log.d(TAG, "ExternalStorage primary path: $path")
                    return path
                }
            } else if (isDownloadsDocument(uri)) {
                Log.d(TAG, "It's a DownloadsDocument URI")
                val docId = DocumentsContract.getDocumentId(uri)
                Log.d(TAG, "Downloads docId: $docId")
                
                // Try to handle msf: prefix by querying MediaStore
                if (docId.startsWith("msf:")) {
                    val id = docId.substringAfter("msf:")
                    Log.d(TAG, "Extracted msf id: $id")
                    
                    // Try Images first
                    var path = queryMediaStore(context, MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                    if (path != null) {
                        Log.d(TAG, "Found in MediaStore.Images: $path")
                        return path
                    }
                    
                    // Try Videos
                    path = queryMediaStore(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id)
                    if (path != null) {
                        Log.d(TAG, "Found in MediaStore.Video: $path")
                        return path
                    }
                    
                    // Try Audio
                    path = queryMediaStore(context, MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                    if (path != null) {
                        Log.d(TAG, "Found in MediaStore.Audio: $path")
                        return path
                    }
                    
                    Log.d(TAG, "Not found in MediaStore, trying Downloads provider")
                }
                
                // Try raw: prefix
                if (docId.startsWith("raw:")) {
                    val path = docId.substringAfter("raw:")
                    Log.d(TAG, "Raw path: $path")
                    return path
                }
                
                // Try normal id with Downloads provider
                try {
                    val id = docId.toLong()
                    val contentUri = ContentUris.withAppendedId(
                        Uri.parse("content://downloads/public_downloads"),
                        id
                    )
                    Log.d(TAG, "Downloads contentUri: $contentUri")
                    val path = getDataColumn(context, contentUri, null, null)
                    if (path != null) {
                        return path
                    }
                } catch (e: NumberFormatException) {
                    Log.e(TAG, "Failed to parse docId as number", e)
                }
            } else if (isMediaDocument(uri)) {
                Log.d(TAG, "It's a MediaDocument URI")
                val docId = DocumentsContract.getDocumentId(uri)
                val split = docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
                val type = split[0]
                
                var contentUri: Uri? = null
                when (type) {
                    "image" -> contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    "video" -> contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    "audio" -> contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                }
                
                val selection = "_id=?"
                val selectionArgs = arrayOf(split[1])
                
                Log.d(TAG, "Media contentUri: $contentUri, id: ${split[1]}")
                return getDataColumn(context, contentUri, selection, selectionArgs)
            }
        } else if ("content".equals(uri.scheme, ignoreCase = true)) {
            Log.d(TAG, "It's a content URI")
            return if (isGooglePhotosUri(uri)) uri.lastPathSegment else getDataColumn(context, uri, null, null)
        } else if ("file".equals(uri.scheme, ignoreCase = true)) {
            Log.d(TAG, "It's a file URI")
            return uri.path
        }
        
        Log.d(TAG, "All methods failed, trying to get display name and check common paths")
        return tryCommonPaths(context, uri)
    }

    private fun queryMediaStore(context: Context, contentUri: Uri, id: String): String? {
        val selection = "_id=?"
        val selectionArgs = arrayOf(id)
        return getDataColumn(context, contentUri, selection, selectionArgs)
    }

    private fun tryCommonPaths(context: Context, uri: Uri): String? {
        val fileName = getFileName(context, uri) ?: return null
        Log.d(TAG, "Looking for file: $fileName")
        
        // Try common directories
        val directories = listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
            File(Environment.getExternalStorageDirectory(), "Download"),
            File(Environment.getExternalStorageDirectory(), "Pictures"),
            File(Environment.getExternalStorageDirectory(), "Movies"),
            File(Environment.getExternalStorageDirectory(), "DCIM")
        )
        
        for (dir in directories) {
            if (dir != null && dir.exists()) {
                val file = File(dir, fileName)
                if (file.exists()) {
                    Log.d(TAG, "Found in ${dir.absolutePath}: ${file.absolutePath}")
                    return file.absolutePath
                }
            }
        }
        
        Log.d(TAG, "File not found in common paths")
        return null
    }

    private fun getDataColumn(
        context: Context, 
        uri: Uri?, 
        selection: String?, 
        selectionArgs: Array<String>?
    ): String? {
        var cursor: Cursor? = null
        val column = "_data"
        val projection = arrayOf(column)
        
        try {
            cursor = context.contentResolver.query(uri!!, projection, selection, selectionArgs, null)
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndexOrThrow(column)
                val path = cursor.getString(index)
                Log.d(TAG, "getDataColumn found path: $path")
                return path
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in getDataColumn", e)
        } finally {
            cursor?.close()
        }
        return null
    }

    private fun getFileName(context: Context, uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            val cursor = context.contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        result = it.getString(nameIndex)
                    }
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result!!.lastIndexOf('/')
            if (cut != -1) {
                result = result!!.substring(cut + 1)
            }
        }
        return result
    }

    private fun isExternalStorageDocument(uri: Uri): Boolean {
        return "com.android.externalstorage.documents" == uri.authority
    }

    private fun isDownloadsDocument(uri: Uri): Boolean {
        return "com.android.providers.downloads.documents" == uri.authority
    }

    private fun isMediaDocument(uri: Uri): Boolean {
        return "com.android.providers.media.documents" == uri.authority
    }

    private fun isGooglePhotosUri(uri: Uri): Boolean {
        return "com.google.android.apps.photos.content" == uri.authority
    }
}
