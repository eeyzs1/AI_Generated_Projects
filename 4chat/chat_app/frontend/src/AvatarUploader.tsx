import React, { useState, useRef, useEffect } from 'react';
import './AvatarStyles.css';

interface AvatarUploaderProps {
  onAvatarSelected: (avatar: string) => void;
  onRemoveAvatar?: () => void;
  defaultAvatar?: string;
}

const AvatarUploader: React.FC<AvatarUploaderProps> = ({ onAvatarSelected, onRemoveAvatar, defaultAvatar = '' }) => {
  const [previewImage, setPreviewImage] = useState<string>('');
  const [isCropping, setIsCropping] = useState(false);
  const [cropBox, setCropBox] = useState({ x: 0, y: 0, size: 200 });
  const [previewSize, setPreviewSize] = useState({ width: 400, height: 300 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragType, setDragType] = useState<'move' | 'resize' | null>(null);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [resizeHandle, setResizeHandle] = useState<'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const imageContainerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  // 默认头像列表
  const defaultAvatars = [
    '/static/avatars/default/default1.png',
    '/static/avatars/default/default2.png',
    '/static/avatars/default/default3.png',
    '/static/avatars/default/default4.png',
    '/static/avatars/default/default5.png'
  ];
  
  // 处理默认头像选择
  const handleDefaultAvatarSelect = (avatar: string) => {
    onAvatarSelected(avatar);
    setIsCropping(false);
    setPreviewImage('');
  };
  
  // 处理头像上传
  const handleAvatarUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    // 显示预览
    setPreviewImage(URL.createObjectURL(file));
    setIsCropping(true);
    
    // 加载图像并获取尺寸
    const img = new Image();
    img.onload = () => {
      // 计算预览窗口大小
      const maxPreviewWidth = 600;
      const maxPreviewHeight = 400;
      
      let width = img.width;
      let height = img.height;
      
      // 调整预览窗口大小以适应图像
      if (width > maxPreviewWidth || height > maxPreviewHeight) {
        const widthRatio = maxPreviewWidth / width;
        const heightRatio = maxPreviewHeight / height;
        const ratio = Math.min(widthRatio, heightRatio);
        width = width * ratio;
        height = height * ratio;
      }
      
      setPreviewSize({ width, height });
      
      // 初始化选择框位置和大小
      const defaultSize = 200;
      const size = Math.min(defaultSize, Math.min(width, height));
      
      // 居中显示选择框
      const centerX = (width - size) / 2;
      const centerY = (height - size) / 2;
      setCropBox({ x: centerX, y: centerY, size });
    };
    img.src = URL.createObjectURL(file);
  };
  
  // 处理鼠标按下事件
  const handleMouseDown = (e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    const rect = e.currentTarget.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    
    // 计算选择框的实际位置（相对于图像容器）
    const boxLeft = cropBox.x;
    const boxTop = cropBox.y;
    
    // 检查是否点击在调整大小的手柄上
    const handleSize = 15;
    
    // 检查四个角的调整手柄
    // 左上角
    if (mouseX >= boxLeft - handleSize && mouseX <= boxLeft + handleSize && mouseY >= boxTop - handleSize && mouseY <= boxTop + handleSize) {
      setDragType('resize');
      setResizeHandle('top-left');
      setIsDragging(true);
      setDragStart({ x: e.clientX, y: e.clientY });
    }
    // 右上角
    else if (mouseX >= boxLeft + cropBox.size - handleSize && mouseX <= boxLeft + cropBox.size + handleSize && mouseY >= boxTop - handleSize && mouseY <= boxTop + handleSize) {
      setDragType('resize');
      setResizeHandle('top-right');
      setIsDragging(true);
      setDragStart({ x: e.clientX, y: e.clientY });
    }
    // 左下角
    else if (mouseX >= boxLeft - handleSize && mouseX <= boxLeft + handleSize && mouseY >= boxTop + cropBox.size - handleSize && mouseY <= boxTop + cropBox.size + handleSize) {
      setDragType('resize');
      setResizeHandle('bottom-left');
      setIsDragging(true);
      setDragStart({ x: e.clientX, y: e.clientY });
    }
    // 右下角
    else if (mouseX >= boxLeft + cropBox.size - handleSize && mouseX <= boxLeft + cropBox.size + handleSize && mouseY >= boxTop + cropBox.size - handleSize && mouseY <= boxTop + cropBox.size + handleSize) {
      setDragType('resize');
      setResizeHandle('bottom-right');
      setIsDragging(true);
      setDragStart({ x: e.clientX, y: e.clientY });
    }
    else {
      // 点击在图像范围内的任何位置，开始拖动选择框
      setDragType('move');
      setIsDragging(true);
      setDragStart({ x: e.clientX, y: e.clientY });
    }
  };
  
  // 处理鼠标移动事件
  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!isDragging) return;
    e.preventDefault();
    
    const rect = e.currentTarget.getBoundingClientRect();
    
    if (dragType === 'move') {
      // 拖动选择框
      const deltaX = e.clientX - dragStart.x;
      const deltaY = e.clientY - dragStart.y;
      
      setCropBox(prev => {
        const newX = prev.x + deltaX;
        const newY = prev.y + deltaY;
        
        // 确保选择框不超出图像边界
        const maxX = previewSize.width - prev.size;
        const maxY = previewSize.height - prev.size;
        
        return {
          ...prev,
          x: Math.max(0, Math.min(maxX, newX)),
          y: Math.max(0, Math.min(maxY, newY))
        };
      });
      
      // 更新拖动起点
      setDragStart({ x: e.clientX, y: e.clientY });
    } else if (dragType === 'resize' && resizeHandle) {
      // 调整选择框大小
      const deltaX = e.clientX - dragStart.x;
      const deltaY = e.clientY - dragStart.y;
      
      setCropBox(prev => {
        let newSize = prev.size;
        
        // 计算缩放因子（基于鼠标移动距离）
        const scaleFactor = Math.sqrt(deltaX * deltaX + deltaY * deltaY) * 0.5;
        
        // 左侧两个点的逻辑与右侧两个点的逻辑相反
        let isEnlarging = false;
        
        switch (resizeHandle) {
          case 'top-left':
            // 左侧点：与右侧点逻辑相反
            // 向左上拖动放大，向右下拖动缩小
            isEnlarging = deltaX < 0 || deltaY < 0;
            break;
          case 'top-right':
            // 右侧点：向右上拖动放大，向左下拖动缩小
            isEnlarging = deltaX > 0 || deltaY < 0;
            break;
          case 'bottom-left':
            // 左侧点：与右侧点逻辑相反
            // 向左下拖动放大，向右上拖动缩小
            isEnlarging = deltaX < 0 || deltaY > 0;
            break;
          case 'bottom-right':
            // 右侧点：向右下拖动放大，向左上拖动缩小
            isEnlarging = deltaX > 0 || deltaY > 0;
            break;
        }
        
        // 计算图像的最短边
        const minImageSize = Math.min(previewSize.width, previewSize.height);
        
        // 根据拖动方向调整大小
        if (isEnlarging) {
          // 放大选择框
          newSize = Math.min(minImageSize, prev.size + scaleFactor);
        } else {
          // 缩小选择框
          newSize = Math.max(100, prev.size - scaleFactor);
        }
        
        // 将缩放数值近似成整数
        newSize = Math.round(newSize);
        
        // 计算中心点偏移，保持选择框中心位置不变
        const centerX = prev.x + prev.size / 2;
        const centerY = prev.y + prev.size / 2;
        const newX = centerX - newSize / 2;
        const newY = centerY - newSize / 2;
        
        // 确保选择框不超出图像边界
        const maxX = previewSize.width - newSize;
        const maxY = previewSize.height - newSize;
        
        return {
          x: Math.max(0, Math.min(maxX, newX)),
          y: Math.max(0, Math.min(maxY, newY)),
          size: newSize
        };
      });
      
      // 更新拖动起点
      setDragStart({ x: e.clientX, y: e.clientY });
    }
  };
  
  // 处理鼠标松开事件
  const handleMouseUp = () => {
    setIsDragging(false);
    setDragType(null);
    setResizeHandle(null);
  };
  
  // 处理滚轮事件
  const handleWheel = (e: WheelEvent) => {
    // 阻止默认滚动行为
    e.preventDefault();
    
    // 计算缩放因子
    const scaleFactor = e.deltaY > 0 ? 0.9 : 1.1;
    
    // 更新选择框大小
    setCropBox(prev => {
      // 计算新的大小
      let newSize = Math.max(100, Math.min(Math.min(previewSize.width, previewSize.height), prev.size * scaleFactor));
      // 将缩放数值近似成整数
      newSize = Math.round(newSize);
      
      // 计算中心点偏移，保持选择框中心位置不变
      const centerX = prev.x + prev.size / 2;
      const centerY = prev.y + prev.size / 2;
      const newX = centerX - newSize / 2;
      const newY = centerY - newSize / 2;
      
      // 确保选择框不超出图像边界
      const maxX = previewSize.width - newSize;
      const maxY = previewSize.height - newSize;
      
      return {
        x: Math.max(0, Math.min(maxX, newX)),
        y: Math.max(0, Math.min(maxY, newY)),
        size: newSize
      };
    });
  };
  
  // 添加原生滚轮事件监听器
  useEffect(() => {
    if (isCropping && imageContainerRef.current) {
      const imageContainer = imageContainerRef.current;
      imageContainer.addEventListener('wheel', handleWheel, { passive: false });
      
      return () => {
        imageContainer.removeEventListener('wheel', handleWheel);
      };
    }
  }, [isCropping, previewSize]);
  
  // 将base64转换为File对象
  const dataURLtoFile = (dataurl: string, filename: string): File => {
    const arr = dataurl.split(',');
    const mime = arr[0].match(/:(.*?);/)?.[1] || 'image/jpeg';
    const bstr = atob(arr[1]);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
      u8arr[n] = bstr.charCodeAt(n);
    }
    return new File([u8arr], filename, { type: mime });
  };
  
  // 处理裁剪和上传
  const handleCropAndUpload = async () => {
    if (!fileInputRef.current?.files?.[0]) return;
    
    const file = fileInputRef.current.files[0];
    
    try {
      // 创建一个新的canvas用于裁剪
      const cropCanvas = document.createElement('canvas');
      cropCanvas.width = 80;
      cropCanvas.height = 80;
      const ctx = cropCanvas.getContext('2d');
      
      if (!ctx) {
        throw new Error('Canvas context not found');
      }
      
      // 加载图片并进行裁剪
      const img = new Image();
      
      // 使用Promise处理图片加载
      const imageLoaded = new Promise<void>((resolve, reject) => {
        img.onload = () => resolve();
        img.onerror = () => reject(new Error('Failed to load image'));
      });
      
      img.src = URL.createObjectURL(file);
      await imageLoaded;
      
      // 获取选择框的位置和大小
      const { x, y, size } = cropBox;
      
      // 绘制圆形裁剪路径
      ctx.beginPath();
      ctx.arc(40, 40, 40, 0, 2 * Math.PI);
      ctx.clip();
      
      // 计算预览窗口到原始图像的缩放比例
      const scaleX = img.width / previewSize.width;
      const scaleY = img.height / previewSize.height;
      
      // 绘制裁剪后的图片，确保缩放到80x80大小
      ctx.drawImage(
        img,
        x * scaleX, // 转换为原始图像的x坐标
        y * scaleY, // 转换为原始图像的y坐标
        size * scaleX, // 转换为原始图像的宽度
        size * scaleY, // 转换为原始图像的高度
        0, // 目标x坐标
        0, // 目标y坐标
        80, // 目标宽度
        80 // 目标高度
      );
      
      // 将canvas转换为base64
      const compressedImageDataUrl = cropCanvas.toDataURL('image/jpeg', 0.7);
      
      // 调用回调函数，返回裁剪后的头像base64
      onAvatarSelected(compressedImageDataUrl);
      
      // 重置状态
      setIsCropping(false);
      setPreviewImage('');
      setCropBox({ x: 0, y: 0, size: 200 });
      setPreviewSize({ width: 400, height: 300 });
    } catch (err) {
      console.error('Avatar crop error:', err);
      // 重置状态
      setIsCropping(false);
      setPreviewImage('');
      setCropBox({ x: 0, y: 0, size: 200 });
      setPreviewSize({ width: 400, height: 300 });
    }
  };
  
  // 处理移除头像
  const handleRemoveAvatar = () => {
    // 清空文件输入
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
    // 调用回调函数
    if (onRemoveAvatar) {
      onRemoveAvatar();
    }
  };
  
  return (
    <div className="avatar-uploader">
      <div className="default-avatars">
        {defaultAvatars.map((defaultAvatar, index) => (
          <div 
            key={index} 
            className={`avatar-option ${defaultAvatar === defaultAvatars.find(a => a === defaultAvatar) ? 'selected' : ''}`}
            onClick={() => handleDefaultAvatarSelect(defaultAvatar)}
          >
            <img src={defaultAvatar} alt={`Default avatar ${index + 1}`} />
          </div>
        ))}
      </div>
      <div className="upload-avatar">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleAvatarUpload}
        />
        {isCropping && previewImage && (
          <div className="image-preview">
            <h4>Preview and Crop</h4>
            <div 
              className="crop-container"
              style={{
                width: `${previewSize.width}px`,
                height: `${previewSize.height}px`,
                overflow: 'hidden',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center'
              }}
            >
              <div 
                ref={imageContainerRef}
                className="image-container"
                onMouseDown={handleMouseDown}
                onMouseMove={handleMouseMove}
                onMouseUp={handleMouseUp}
                onMouseLeave={handleMouseUp}
                style={{ 
                  cursor: dragType === 'move' ? 'grabbing' : 
                         dragType === 'resize' ? 
                         (resizeHandle === 'top-left' || resizeHandle === 'bottom-right') ? 'nwse-resize' : 'nesw-resize' : 
                         'grab',
                  position: 'relative',
                  width: '100%',
                  height: '100%',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  userSelect: 'none',
                  touchAction: 'none',
                  overflow: 'hidden',
                  overscrollBehavior: 'none'
                }}
              >
                <img 
                  src={previewImage} 
                  alt="Preview" 
                  className="preview-image"
                  style={{
                    display: 'block',
                    maxWidth: '100%',
                    maxHeight: '100%',
                    objectFit: 'contain',
                    zIndex: 1
                  }}
                />
                <div 
                  className="crop-frame"
                  style={{
                    position: 'absolute',
                    left: '0',
                    top: '0',
                    width: `${cropBox.size}px`,
                    height: `${cropBox.size}px`,
                    transform: `translate(${cropBox.x}px, ${cropBox.y}px)`,
                    border: '2px solid #3498db',
                    borderRadius: '50%',
                    zIndex: 2,
                    pointerEvents: 'none',
                    backgroundColor: 'rgba(255, 255, 255, 0.3)'
                  }}
                >
                  <div className="crop-guides">
                    <div className="guide-top"></div>
                    <div className="guide-bottom"></div>
                    <div className="guide-left"></div>
                    <div className="guide-right"></div>
                  </div>
                  <div className="resize-handles">
                    <div className="resize-handle top-left"></div>
                    <div className="resize-handle top-right"></div>
                    <div className="resize-handle bottom-left"></div>
                    <div className="resize-handle bottom-right"></div>
                  </div>
                </div>
              </div>
            </div>
            <div className="crop-actions">
              <button type="button" onClick={handleCropAndUpload}>Confirm</button>
              <button type="button" onClick={() => {
                setIsCropping(false);
                setPreviewImage('');
                if (fileInputRef.current) {
                  fileInputRef.current.value = '';
                }
                setCropBox({ x: 0, y: 0, size: 200 });
                setPreviewSize({ width: 400, height: 300 });
              }}>Cancel</button>
            </div>
          </div>
        )}
      </div>
      {defaultAvatar && (
        <div className="selected-avatar">
          <img src={defaultAvatar} alt="Selected avatar" />
          <button type="button" onClick={handleRemoveAvatar}>Remove</button>
        </div>
      )}
    </div>
  );
};

export default AvatarUploader;