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
  rotate(30deg, polygon.regular(fill: c, stroke: black, size: size, vertices: 6))
}

// Will draw a grid of hex with cell occupied in g and size in n
// It will draw also the labels of the columns and rows
#let grid(g, n, hexagonSize) = {
  let gridHorPadding = 5pt;
  let gridVerPadding = 2pt;

  let letterLine = range(n).map(i => {
    align(center, str.from-unicode(97 + i))
  });

  let maxChars = str(n).len();

  style(styles => {
    let rowNumbersSize = measure([1], styles).width;
    stack(
      dir:ttb,
      spacing: none,
      table( // Use grid ?
        stroke: black,
        inset: (left : 0pt, right: 5pt), // This value is just tested, should rather be calculated, and this doesn't work well with left alignement (to be fixed later)
        columns: (maxChars * rowNumbersSize + gridHorPadding,) + (hexagonSize,)*n + (hexagonSize/2 * n + maxChars * rowNumbersSize,),
        [],
        ..letterLine,
        []
      ),
      v(gridVerPadding),
      ..range(n).map(i => {
        let l = str(i+1).len();
        stack(
          dir: ltr,
          spacing: none,
          {
            h(hexagonSize/2 * i - (l - maxChars) * rowNumbersSize);
          },
          align(horizon, str(i+1)),
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
          align(horizon, str(i+1)),
          {
            h(hexagonSize/2 * (n -i) - (l - maxChars) * rowNumbersSize);
          }
        )
      }),
      v(gridVerPadding),
      table( // Use grid ?
        stroke: black,
        columns: (hexagonSize/2 * (n -1) + maxChars * rowNumbersSize,) + (hexagonSize,)*n + (maxChars * rowNumbersSize + gridHorPadding,),
        [],
        ..letterLine,
        []
      )
    )
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

  let row = int(input.slice(position));
  return (row, column -1);
}

#let gridFromSGF(input, hexagonSize: 30pt) = {
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

  grid(position, size, hexagonSize);
}
