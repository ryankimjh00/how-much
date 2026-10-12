"""실제 사진과 사람이 정한 영역을 동일 PNG로 준비한다. 인식 결과는 사용하지 않는다."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[3]
SOURCES = Path(__file__).resolve().parent / 'sources'
OUT = Path('/tmp/receipt-ocr-comparison/inputs')
OUT.mkdir(parents=True, exist_ok=True)
manifest = []


def save(case_id, image, kind, expected=None, bounds=None, photo_id=None):
    path = OUT / f'{case_id}.png'
    image.save(path)
    manifest.append(dict(id=case_id, path=str(path), kind=kind, expected=expected,
                         bounds=bounds, photo_id=photo_id or case_id,
                         width=image.width, height=image.height,
                         sha256=hashlib.sha256(path.read_bytes()).hexdigest()))


def photo(photo_id, path):
    image = ImageOps.exif_transpose(Image.open(path)).convert('RGB')
    save(photo_id, image, 'whole')
    return image


def region(photo_id, image, field, index, rect, expected, reference=None):
    sx, sy = (image.width/reference[0], image.height/reference[1]) if reference else (1, 1)
    left, top, right, bottom = rect
    bounds = [max(0, math.floor(left*sx)), max(0, math.floor(top*sy)),
              min(image.width, math.ceil(right*sx)), min(image.height, math.ceil(bottom*sy))]
    save(f'{photo_id}-{field}-{index:02}', image.crop(bounds), field, expected, bounds, photo_id)


kyobo1 = photo('kyobo-first-original', SOURCES / 'kyobo-first-original.jpg')
qys = [1090,1186,1278,1374,1473,1580,1685,1790]
names = ['포스트잇/670-5AN-5/알뜰팩','[JR] 스티커미니/101-FOOD.01',
         '[JR] 스티커미니/112/FOOD.04','[JR] 스티커미니/120-FOOD.05',
         '[JR] 스티커미니 132-FOOD.07','[JR] 스티커 CEREAL 301/SWEET CAKE',
         '[JR] 스티커 CEREAL 303/LEAVES','[JR] 스티커/CEREAL 304-CATS']
for i, (y, name, amount) in enumerate(zip(qys,names,[9600,1300,1300,1300,1300,3500,3500,3500])):
    region('kyobo-first-original',kyobo1,'quantity',i,(730,y-30,797,y+30),'1',(1368,1824))
    region('kyobo-first-original',kyobo1,'amount',i,(875,y-34,1020,y+34),str(amount),(1368,1824))
    region('kyobo-first-original',kyobo1,'name',i,(210,y-78,840,y-28),name,(1368,1824))
    region('kyobo-first-original',kyobo1,'row',i,(210,y-34,1020,y+34),None,(1368,1824))

kyobo2 = photo('kyobo-second-original',SOURCES / 'kyobo-second-original.jpg')
positions = [(817,87),(817,185),(819,282),(822,379),(824,476),(827,576),(831,676),(834,771),(837,870),(838,969),(840,1064)]
names2 = ['[JR] 스티커 CEREAL 312-DONETS','수첩식 포스트잇/형광','수첩식 포스트잇/파스텔',
          '[JR] 스티커/1167/STREET FOOD','[JR] 스티커/1177/OLD BAKERY','[JR] 스티커/1173/FOOD TRIP #8',
          '[MW] 81763/페인팅 스티커/스윗츠','[MW] 81764/페인팅 스티커/커피',
          "[JR] 스티커 1204-LET’S BAKE!",'[JR] 스티커/1202-LUNCH BOX','프리즘 220 라인 밴드 노트/크림']
for i,((x,y),name,amount) in enumerate(zip(positions,names2,[4000,3100,3100,2500,2500,2500,4900,4900,2500,2500,16800])):
    region('kyobo-second-original',kyobo2,'quantity',i,(x-28,y-26,x+28,y+26),'1',(1368,1824))
    region('kyobo-second-original',kyobo2,'amount',i,(925,y-32,1090,y+32),str(amount),(1368,1824))
    region('kyobo-second-original',kyobo2,'name',i,(165,y-67,1090,y-18),name,(1368,1824))
    region('kyobo-second-original',kyobo2,'row',i,(620,y-26,1260,y+26),None,(1368,1824))

corrected = photo('kyobo-second-corrected',ROOT/'docs/ocr-debug/quantity-one-20261011/kyobo-corrected.png')
for i,(y,amount) in enumerate(zip([193,406,622,837,1063,1280,1499,1720,1937,2151,2373],[4000,3100,3100,2500,2500,2500,4900,4900,2500,2500,16800])):
    region('kyobo-second-corrected',corrected,'quantity',i,(1350,y-55,1460,y+55),'1')
    region('kyobo-second-corrected',corrected,'amount',i,(1640,y-55,1980,y+55),str(amount))
    region('kyobo-second-corrected',corrected,'row',i,(1000,y-55,1980,y+55),None)

samseon=photo('samseon-original',SOURCES / 'samseon-original.jpg')
for i,(y,name,amount) in enumerate([(687,'삼선짜장',12000),(773,'제로펩시',2000)]):
    region('samseon-original',samseon,'quantity',i,(475,y-27,530,y+27),'1',(1368,1824))
    region('samseon-original',samseon,'amount',i,(810,y-30,975,y+30),str(amount),(1368,1824))
    region('samseon-original',samseon,'name',i,(345,y-57,550,y-18),name,(1368,1824))
    region('samseon-original',samseon,'row',i,(185,y-30,975,y+30),None,(1368,1824))

trader_names=['퍼실 딥클린 파워젤','달콤한 베지밀B 검은','스너글 섬유유연제 블',
             '닥터텅물티케어칫솔','낙지젓1kg','국내산냉동옛날삼겹살','해표 식용유 1.9L*2입',
             'TS 뽑아쓰는 키친타월','설탕대신 스테비아 1.','TS 고칼슘 저지방',
             '유한락스 레귤러 5.8L','슈가버블 레몬트리쉬','코디 더 부드러운 롤',
             '어기즈 1단계 850g','마미손 고무장갑 6입']
quantities=[3,2,2,1,1,1,1,1,1,2,1,1,1,1,1]
amounts=[80940,33760,37960,12980,17980,36980,13980,13480,11980,11760,8880,12980,14980,19980,9980]
traders=photo('traders-original',SOURCES / 'traders-original.jpg')
for i,(y,q,a) in enumerate(zip([187,214,226,238,250,274,287,312,325,338,356,368,381,394,406],quantities,amounts)):
    region('traders-original',traders,'quantity',i,(222,y-7,243,y+7),str(q))
    region('traders-original',traders,'amount',i,(255,y-8,315,y+8),str(a))
    region('traders-original',traders,'row',i,(28,y-8,315,y+8),None)

recreated=photo('traders-recreated',SOURCES / 'traders-recreated.png')
for i,(y,q,a,name) in enumerate(zip([477,548,584,620,657,713,749,823,861,897,953,991,1027,1063,1100],quantities,amounts,trader_names)):
    region('traders-recreated',recreated,'quantity',i,(654,y-19,702,y+19),str(q))
    region('traders-recreated',recreated,'amount',i,(744,y-20,889,y+20),str(a))
    region('traders-recreated',recreated,'row',i,(490,y-20,889,y+20),None)

oldrow=photo('samseon-pepsi-saved-row',ROOT/'docs/ocr-debug/samseon-row-20261008/pepsi-row.png')
region('samseon-pepsi-saved-row',oldrow,'quantity',0,(450,0,530,64),'1')
region('samseon-pepsi-saved-row',oldrow,'amount',0,(960,0,1150,64),'2000')
# 빈 영역의 오확정 위험도 비교하되 백지는 실제 사진 성적과 구분한다.
save('blank',Image.new('RGB',(120,100),'white'),'blank','')
Path('/tmp/receipt-ocr-comparison/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(ROOT/'docs/ocr-comparison/20261011/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print('prepared',len(manifest),'inputs')
