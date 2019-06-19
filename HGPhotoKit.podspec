Pod::Spec.new do |s|
    s.name         = 'HGPhotoKit'
    s.version      = '0.0.2'
    s.summary      = 'Hago3.0 图片工具类' 
    s.homepage     = "https://github.com/pengweijunPanda/HGPhotoKit.git"
    s.license      = "MIT"
    s.authors      = { 'pengweijun' => '51365338@qq.com'}
    s.platform     = :ios,'7.0'
    s.source       = { :git => "https://github.com/pengweijunPanda/HGPhotoKit.git", :tag => s.version }
    s.source_files = "HGPhotoKit/Classes/*.{h,m}" 
    s.requires_arc = true 


    s.dependency 'YYKit'
end
