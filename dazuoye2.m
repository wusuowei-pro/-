clear; clc; close all;

%% 1. 选择图片
[filename, pathname] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp'});
if isequal(filename, 0)
    disp('未选择文件，程序退出');
    return;
end
img = imread(fullfile(pathname, filename));

%% 2. 图像预处理：灰度化
if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end
gray = im2double(gray);

%% 3. 降噪：中值滤波
denoised = medfilt2(gray, [3 3]);

%% 4. 二值化分割（Otsu自动阈值）
level = graythresh(denoised);
bw = imbinarize(denoised, level);

if mean(bw(:)) > 0.5
    bw = ~bw;
end

%% 5. 形态学处理：去除小面积噪声
bw = bwareaopen(bw, 30);   

%% 6. 轮廓特征提取：标记连通域，定位最大区域（数字）
stats = regionprops(bw, 'BoundingBox', 'Area', 'Image');
if isempty(stats)
    error('二值图像中未检测到任何连通区域，请检查输入图片。');
end
[~, idx] = max([stats.Area]);        
digitRegion = stats(idx);
digitImg = digitRegion.Image;       

bwBound = bwboundaries(bw);

%% 7. 生成0~9标准字体模板（模板大小28×28）
templateSize = [100, 100];
templates = cell(1, 10);
fprintf('正在生成模板...\n');
for d = 0:9
    fig = figure('Visible', 'off', 'Color', 'white', 'Position', [100 100 100 100]);
    ax = axes('Parent', fig, 'Position', [0 0 1 1], 'Visible', 'off');
    text(ax, 0.5, 0.5, num2str(d), 'FontUnits', 'normalized', 'FontSize', 0.8, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'Color', 'black', 'FontWeight', 'bold');
    drawnow;
    frame = getframe(fig);
    close(fig);
    
    tmpGray = rgb2gray(frame.cdata);
    tmpBw = imbinarize(tmpGray);
    tmpBw = ~tmpBw;                    
    [r, c] = find(tmpBw);
    if ~isempty(r)
        tmpBw = tmpBw(min(r):max(r), min(c):max(c)); 
    end
    tmpBw = imresize(tmpBw, templateSize);       
    templates{d+1} = tmpBw;
end
fprintf('模板生成完成。\n');

figure('Name', '0~9标准模板', 'NumberTitle', 'off');
for d = 1:10
    subplot(2, 5, d);
    imshow(templates{d}, 'InitialMagnification', 'fit');
    title(num2str(d-1));
end
% ===========================================

%% 8. 归一化待识别数字并执行模板匹配
digitResized = imresize(digitImg, templateSize);
scores = zeros(1, 10);
for d = 1:10
    scores(d) = corr2(digitResized, templates{d});
end
[~, matchedIdx] = max(scores);
recognizedDigit = matchedIdx - 1;      

%% 9. 可视化：展示各步骤结果
figure('Name', '数字识别过程', 'NumberTitle', 'off');

subplot(2,4,1); imshow(img);       title('原图');
subplot(2,4,2); imshow(denoised);  title('降噪后');
subplot(2,4,3); imshow(bw);        title('二值化分割');
subplot(2,4,4); imshow(gray);      title('轮廓提取'); hold on;
for k = 1:length(bwBound)
    boundary = bwBound{k};
    plot(boundary(:,2), boundary(:,1), 'r', 'LineWidth', 2);
end
hold off;

subplot(2,4,5); imshow(digitImg);  title('提取的数字区域');
subplot(2,4,6); bar(0:9, scores);  xlabel('数字'); ylabel('相关系数');
title('模板匹配得分'); grid on;
subplot(2,4,7); imshow(templates{matchedIdx}); title(['模板: ', num2str(recognizedDigit)]);
subplot(2,4,8); text(0.1, 0.5, ['识别结果: ', num2str(recognizedDigit)], ...
                     'FontSize', 20, 'FontWeight', 'bold'); axis off;

%% 10. 命令行输出结果
fprintf('识别结果：%d\n', recognizedDigit);