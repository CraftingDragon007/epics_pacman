import sys
import xml.etree.ElementTree as ET

def main()
    tree = ET.parse(sys.argv[1])
    root = tree.getroot()
    entries = []
    for button in root.findall(.widget[@class='QPushButton'])
        rect = button.find(property[@name='geometry']rect)
        if rect is None
            continue
        x = rect.findtext(x)
        y = rect.findtext(y)
        width = rect.findtext(width)
        height = rect.findtext(height)
        entries.append((x, y, width, height))
    print({)
    for x, y, w, h in entries
        print(f    {{{x}, {y}, {w}, {h}}},)
    print(})

if __name__ == __main__
    main()
