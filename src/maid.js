require('atom-watcher')();

// global.document = window.document;
// global.navigator = window.navigator;

// global.SpawnSync = require('child_process').spawnSync;
// global.Spawn = require('child_process').spawn;
// var Path = require('path');
// var Fs = require('fs');

// import Path from 'path';
import React from 'react';
import ReactBootstrap from 'react-bootstrap';
import ReactRouterBootstrap from 'react-router-bootstrap';
import Router from 'react-router';

let ModalTrigger = ReactBootstrap.ModalTrigger;
let ListGroup = ReactBootstrap.ListGroup;
let ListGroupItem = ReactBootstrap.ListGroupItem;
let Table = ReactBootstrap.Table;
let Modal = ReactBootstrap.Modal;
let Button = ReactBootstrap.Button;
let Row = ReactBootstrap.Row;
let Col = ReactBootstrap.Col;
let Input = ReactBootstrap.Input;
let ProgressBar = ReactBootstrap.ProgressBar;
let Alert = ReactBootstrap.Alert;
let Nav = ReactBootstrap.Nav;
var Navbar = ReactBootstrap.Navbar;

var NavItemLink = ReactRouterBootstrap.NavItemLink;

var RouteHandler = Router.RouteHandler;
var Route = Router.Route;

var App = React.createClass({
  render() {
    return (
      <div>
        <Navbar brand='Maid' staticTop>
          <Nav>
            <NavItemLink to="transfers">Transfers</NavItemLink>
            <NavItemLink to="rules">Rules</NavItemLink>
            <NavItemLink to="scrape">Scrape</NavItemLink>
          </Nav>
        </Navbar>
        <RouteHandler />
      </div>
    );
  }
});

import Transfers from './transfers';
import Rules from './rules.js';
import Scrape from './scrape_browser.js';

var routes = (
  <Route handler={App} path="/">
    <Route name="transfers" path="transfers" handler={Transfers} />
    <Route name='rules' path='rules' handler={Rules} />
    <Route name="scrape" path="scrape" handler={Scrape} />
  </Route>
);

Router.run(routes, function (Handler) {
  React.render(<Handler/>, document.body);
});
