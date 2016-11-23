import React from 'react'
import {Link} from 'app/router'
import Restricted from 'app/restricted'

function UserMenu(props){
  return (
    <div className="ui dropdown pointing" id="profile_menu">
      <div className="menu transition visible">
        <a className="item" href="#/user/profile">
          <span>{props.user.name}</span>
          <i className="ui icon user"></i>
        </a>
        <a className="item" href="#/settings/">
          <span>Settings</span>
          <i className="ui icon settings"></i>
        </a>
        <Restricted perm="logs.view">
          <a className="item" href="#/logs/">
              <span>Logs</span>
              <i className="ui icon book"></i>
          </a>
        </Restricted>
        <a href="#!" className="item" onClick={props.onLogout}>
          <span>Logout</span>
          <i className="ui icon power"></i>
        </a>
      </div>
    </div>
  )
}

export default UserMenu
