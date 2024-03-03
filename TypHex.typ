#import "sgf.typ": parse

#let emptycolor = color.rgb("#fcf9f0")
#let bluecolor = color.rgb("#453cf0")
#let redcolor = color.rgb("#d6202f")

/* 
  Find owner of a cell, depending of the type of the input and its content
  Owners : -1 = empty = e, 0 = blue = b = white, 1 = red = r = black
*/
#let getowner(parameter) = {
  if type(parameter) == int {
    return parameter;
  } else if type(parameter) == str {
    if parameter == "e" or parameter == "empty" {
      return -1;
    }
    if parameter == "b" or parameter == "blue" {
      return 0;
    }
    if parameter == "r" or parameter == "red" {
      return 1;
    }
    return 2;
  }
}

// Simply draw an hexagon
#let hexagon(owner, size) = {
  let c = black;
  let o = getowner(owner);
  if o == -1 {
    c = emptycolor;
  } else if o == 0 {
    c = bluecolor;
  } else if o == 1 {
    c = redcolor;
  } else {
    assert(false, message: "Invalid color");
  }

  // We can't use polygon.regular + rotate without 
  let width = size*calc.cos(30deg);
  box(width: width,
  height: size,
  polygon(
    fill: c,
    stroke: black + 1pt,
    (0%, 25%),
    (50%, 0%),
    (100%, 25%),
    (100%, 75%),
    (50%, 100%),
    (0%, 75%)
  ));
}

// Will draw a grid of hex with cell occupied in g and size in n
// It will draw also the labels of the columns and rows
#let grid(g, n, hexagonSize, gridVerPadding, gridHorPadding, textSize) = {

  // Fixme : shouldn't be limited to one character
  let letterLine = range(n).map(i => {
    align(center, text(textSize, str.from-unicode(65 + i)))
  });

  // The maximum number of chars of the row numbers
  let maxChars = str(n).len();
  // Size of the "top" of an hexagon
  let minusSpacing = hexagonSize/2 * (1 - calc.sin(30deg));
  // The width of an hexagon
  let hexagonWidth = hexagonSize*calc.cos(30deg);

  style(styles => {
    let rowNumbersSize = measure(text(textSize)[1], styles).width;
    let g = stack(
      dir:ttb,
      spacing: -minusSpacing,
      table( // Use grid ?
        stroke: none,
        inset: (left : 0pt, right: 0pt, top: 2pt, bottom: 2pt),
        columns: (maxChars * rowNumbersSize,) + (gridHorPadding,) + (hexagonWidth,)*n + (hexagonWidth/2 * (n -1),) + (gridHorPadding,) + (maxChars * rowNumbersSize,),
        [], [],
        ..letterLine,
        [], [], []
      ),
      v(minusSpacing * 2 + gridVerPadding),
      ..range(n).map(i => {
        let l = str(i+1).len();
        stack(
          dir: ltr,
          spacing: none,
          h(hexagonWidth/2 * i - (l - maxChars) * rowNumbersSize),
          align(horizon, text(textSize, str(i+1))),
          h(gridHorPadding),
          ..range(n).map(j => {
            let c = "e";
            for k in g.keys() {
              if (i,j) in g.at(k) {
                c = k;
              }
            }
            hexagon(c, hexagonSize)
          }),
          h(gridHorPadding),
          align(horizon, text(textSize, str(i+1))),
          h(hexagonWidth/2 * (n -i - 1) - (l - maxChars) * rowNumbersSize)
        )
      }),
      v(minusSpacing * 2 + gridVerPadding),
      table(
        stroke: none,
        inset: (left : 0pt, right: 0pt),
        columns: (hexagonWidth/2 * (n -1),) + (maxChars * rowNumbersSize,) + (gridHorPadding,) + (hexagonWidth,)*n + (gridHorPadding,) + (maxChars * rowNumbersSize,),
        [], [], [],
        ..letterLine,
        [], []
      )
    )
    box({
      let d = measure(g, styles);

      let textHeight = measure(text(textSize)[A], styles).height;
      let topPadding = 4pt + textHeight - gridVerPadding - hexagonSize/2;
      let leftPadding = maxChars * rowNumbersSize + gridHorPadding;
      let gridWidth = n * hexagonWidth;
      let topRight = leftPadding + gridWidth;
      let bottomLeft = d.width - gridWidth - rowNumbersSize * maxChars - 2*gridHorPadding;
    
      // Left
      place(
        polygon(
          fill: blue,
          (leftPadding/2, topPadding/2),
          (0pt, topPadding + 10pt),
          (bottomLeft, d.height),
          (d.width/2, d.height/2),
        )
      );

      // Top
      place(
        polygon(
          fill: red,
          (leftPadding/2, topPadding/2),
          (leftPadding -5pt, 0pt),
          (topRight, 0pt),
          (d.width/2, d.height/2)
        )
      );

      // Right
      place(
        polygon(
          fill: blue,
          (d.width/2, d.height/2),
          (topRight, 0pt),
          (d.width, d.height)
        )
      );

      // Bottom
      place(
        polygon(
          fill: red,
          (d.width/2, d.height/2),
          (bottomLeft, d.height),
          (d.width, d.height)
        )
      );

      g;
    })
  });
}

// Decode "a1" to (0,0)
#let parsePosition(input) = {
  let column = 0;
  let position = 0;

  let isLetter(c) = {
    let c = c.to-unicode();
    return (97 <= c and c <= 122) or (65 <= c and c <= 90)
  }

  while isLetter(input.at(position)) {
    let c = input.at(position).to-unicode();
    column *= 26;
    column += c - 96;
    position += 1;
  }

  let row = int(input.slice(position))-1;
  return (row, column -1);
}

#let gridFromSGF(input, hexagonSize: 30pt, gridVerPadding : 0pt, gridHorPadding : 5pt, textSize : 15pt) = {
  let tree = parse(input);
  assert(tree.FF == "4", message: "Expected SGF version 4");
  let size = int(tree.SZ);
  let position = (
    b: (),
    r: (),
  );

  while tree != () and tree.children != () {
    assert(tree.children.len() == 1, message: "Expected having a 1-ary tree");
    let keys = tree.keys();
    if "AW" in keys {
      for i in tree.AW {
        position.b.push(parsePosition(i))
      }
    }
    if "W" in keys {
      position.b.push(parsePosition(tree.W))
    }
    if "AB" in keys {
      for i in tree.AB {
        position.r.push(parsePosition(i))
      }
    }
    if "B" in keys {
      position.r.push(parsePosition(tree.B))
    }
    tree = tree.children.at(0);
  }

  grid(position, size, hexagonSize, gridVerPadding, gridHorPadding, textSize);
}
