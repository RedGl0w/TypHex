// Basic implementation of a Smart Game Format (SGF) parser
// For specification, see https://www.red-bean.com/sgf/sgf4.html

// We should get rid off whitespaces :
//  White space (space, tab, carriage return, line feed, vertical tab and so on) may appear anywhere between PropValues, Properties, Nodes, Sequences and GameTrees. 
#let getPropIdent(input, position) = {
  let out = "";
  while position < input.len() {
    let c = input.at(position);
    if c == "[" {
      break;
    }
    position += 1;
    out += c;
  }
  assert(input.at(position) == "[", message: "Unexpected end of string while getPropIdent");
  return (position, out);
}

#let getPropValue(input, position) = {
  let out = "";
  let escaped = false;
  while position < input.len() {
    let c = input.at(position);
    position += 1;
    if (c == "]") and (not escaped) {
      break;
    }
    if (c == "\\") and (not escaped) {
      escaped = true;
      continue;
    }
    escaped = false;
    out += c;
  }
  assert(input.at(position -1) == "]", message: "Unexpected end of string while getPropValue")
  return (position, out);
}

#let getPropValues(input, position) = {
  let propValues = ();
  while position < input.len() {
    let c = input.at(position);
    if c == "[" {
      let (p, r) = getPropValue(input, position+1);
      propValues.push(r);
      position = p;
    } else {
      break;
    }
  }
  if propValues.len() == 1 {
    return (position, propValues.at(0));
  }
  return (position, propValues);
}

#let getProp(input, position) = {
  let (p, ident) = getPropIdent(input, position);
  position = p;
  let (p, values) = getPropValues(input, position);
  return (p, ident, values);
}

#let tokenize(input) = {
  let tokens = ();
  let position = 0;
  while position < input.len() {
    let c = input.at(position);
    if c == "(" {
      tokens.push((type: "startTree"));
      position += 1;
      continue;
    }
    if c == ")" {
      tokens.push((type: "endTree"));
      position += 1;
      continue;
    }
    if c == ";" {
      tokens.push((type: "newNode"));
      position += 1;
      continue;
    }
    let (p, ident, values) = getProp(input, position);
    position = p;
    tokens.push((type: "Property", ident: ident, values: values));
    continue;
  }
  return tokens;
}

// Return (new position, node)
#let parseNode(tokens, position) = {
  let n = (children : ());
  while tokens.at(position).type == "Property" {
    let p = tokens.at(position);
    n.insert(p.ident, p.values);
    position += 1;
  }
  return (position, n);
}

#let parseTree(tokens, position) = {
  let tree = ();
  let followedNodes = (); // when tokens are ;a;b;c without another complete tree (with parentheses) between
  
  assert(tokens.at(position) == (type: "startTree"), message: "Expected tree to be parsed in parseTree");
  position += 1;

  while tokens.at(position) == (type: "newNode") {
    let (p, c) = parseNode(tokens, position + 1);
    position = p;
    followedNodes.push(c);
  }
  assert(followedNodes != 1, message: "Expected a root in parseTree");
  while tokens.at(position) == (type: "startTree") {
    let (p, c) = parseTree(tokens, position);
    position = p+1;
    followedNodes.last().children.push(c);
  }
  for c in followedNodes.rev() {
    c.children.push(tree);
    tree = c;
  }
  assert(tokens.at(position) == (type: "endTree"))
  return (position, tree)
}

#let parse(input) = {
  let tokens = tokenize(input);
  let position = 0;
  let (p, tree) = parseTree(tokens, 0);
  return tree;
}
