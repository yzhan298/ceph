import { Component, OnInit, TemplateRef, ViewChild } from '@angular/core';

import { BsModalRef, BsModalService } from 'ngx-bootstrap';

import { UserService } from '../../../shared/api/user.service';
import { DeletionModalComponent } from '../../../shared/components/deletion-modal/deletion-modal.component';
import { EmptyPipe } from '../../../shared/empty.pipe';
import { NotificationType } from '../../../shared/enum/notification-type.enum';
import { CdTableAction } from '../../../shared/models/cd-table-action';
import { CdTableColumn } from '../../../shared/models/cd-table-column';
import { CdTableSelection } from '../../../shared/models/cd-table-selection';
import { Permission } from '../../../shared/models/permissions';
import { AuthStorageService } from '../../../shared/services/auth-storage.service';
import { NotificationService } from '../../../shared/services/notification.service';

@Component({
  selector: 'cd-user-list',
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.scss']
})
export class UserListComponent implements OnInit {
  @ViewChild('userRolesTpl')
  userRolesTpl: TemplateRef<any>;

  permission: Permission;
  tableActions: CdTableAction[];
  columns: CdTableColumn[];
  users: Array<any>;
  selection = new CdTableSelection();

  modalRef: BsModalRef;

  constructor(
    private userService: UserService,
    private emptyPipe: EmptyPipe,
    private modalService: BsModalService,
    private notificationService: NotificationService,
    private authStorageService: AuthStorageService
  ) {
    this.permission = this.authStorageService.getPermissions().user;
    const addAction: CdTableAction = {
      permission: 'create',
      icon: 'fa-plus',
      routerLink: () => '/user-management/users/add',
      name: 'Add'
    };
    const editAction: CdTableAction = {
      permission: 'update',
      icon: 'fa-pencil',
      routerLink: () =>
        this.selection.first() && `/user-management/users/edit/${this.selection.first().username}`,
      name: 'Edit'
    };
    const deleteAction: CdTableAction = {
      permission: 'delete',
      icon: 'fa-times',
      click: () => this.deleteUserModal(),
      name: 'Delete'
    };
    this.tableActions = [addAction, editAction, deleteAction];
  }

  ngOnInit() {
    this.columns = [
      {
        name: 'Username',
        prop: 'username',
        flexGrow: 1
      },
      {
        name: 'Name',
        prop: 'name',
        flexGrow: 1,
        pipe: this.emptyPipe
      },
      {
        name: 'Email',
        prop: 'email',
        flexGrow: 1,
        pipe: this.emptyPipe
      },
      {
        name: 'Roles',
        prop: 'roles',
        flexGrow: 1,
        cellTemplate: this.userRolesTpl
      }
    ];
  }

  getUsers() {
    this.userService.list().subscribe((users: Array<any>) => {
      this.users = users;
    });
  }

  updateSelection(selection: CdTableSelection) {
    this.selection = selection;
  }

  deleteUser(username: string) {
    this.userService.delete(username).subscribe(
      () => {
        this.getUsers();
        this.modalRef.hide();
        this.notificationService.show(NotificationType.success, `Deleted user "${username}"`);
      },
      () => {
        this.modalRef.content.stopLoadingSpinner();
      }
    );
  }

  deleteUserModal() {
    const sessionUsername = this.authStorageService.getUsername();
    const username = this.selection.first().username;
    if (sessionUsername === username) {
      this.notificationService.show(
        NotificationType.error,
        `Failed to delete user "${username}"`,
        `You are currently logged in as "${username}".`
      );
      return;
    }
    this.modalRef = this.modalService.show(DeletionModalComponent, {
      initialState: {
        itemDescription: 'User',
        submitAction: () => this.deleteUser(username)
      }
    });
  }
}
